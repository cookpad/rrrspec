require 'set'
require 'extreme_timeout'
require 'timeout'

module RRRSpec
  module Client
    class SlaveRunner
      attr_reader :key

      TASKQUEUE_TASK_TIMEOUT = -1
      TASKQUEUE_ARBITER_TIMEOUT = 20
      TIMEOUT_EXITCODE = 42
      class SoftTimeoutException < Exception; end

      def initialize(taskset_ref)
        @taskset_ref = taskset_ref
        @rspec_runner = RSpecRunner.new
        @worked_task_refs = Set.new
        @shutdown = false
        @working_path = ENV['RRRSPEC_WORKING_PATH']
      end

      def open(transport)
        if @slave_ref.blank?
          @slave_ref, err = transport.sync_call(:create_slave, RRRSpec.generate_slave_name, @taskset_ref)
          EM.defer do
            begin
              loop(!@shutdown) { work(transport) }
            ensure
              EM.stop_event_loop
            end
          end
        end
      end

      def close(transport)
        # Do nothing
      end

      def spec_timeout_sec(task)
        if task.estimate_sec == nil
          soft_timeout_sec = @unknown_spec_timeout_sec
          hard_timeout_sec = @unknown_spec_timeout_sec + 30
        else
          estimate_sec = task.estimate_sec
          soft_timeout_sec = estimate_sec * 2
          hard_timeout_sec = estimate_sec * 3
        end
        return [soft_timeout_sec, @least_timeout_sec].max, [hard_timeout_sec, @least_timeout_sec].max
      end

      def work(transport)
        task, err = transport.sync_call(:dequeue_task, @taskset_ref)
        if task.blank?
          @shutdown = true
          return
        end
        task_ref, spec_path, hard_timeout_sec, soft_timeout_sec = task
        if @worked_task_refs.include?(task_ref)
          transport.send(:reversed_enqueue_task, task_ref)
          return
        end

        trial_ref, err = transport.sync_call(:create_trial, task_ref, @slave_ref)
        transport.send(:current_trial, @slave_ref, trial_ref)
        @rspec_runner.reset
        stdout, stderr, status = @rspec_runner.setup(File.join(@working_path, spec_path))
        unless status
          transport.send(:finish_trial, trial_ref, 'error', stdout, stderr, nil, nil, nil)
          return
        end

        transport.send(:start_trial, trial_ref)
        formatter = InspectingFormatter.new
        stdout, stderr, status = ExtremeTimeout::timeout(hard_timeout_sec, TIMEOUT_EXITCODE) do
          Timeout::timeout(soft_timeout_sec, SoftTimeoutException) do
            @rspec_runner.run(formatter)
          end
        end
        if status
          transport.send(:finish_trial, trial_ref, formatter.status, stdout, stderr,
                         formatter.passed, formatter.pending, formatter.failed)
        else
          transport.send(:finish_trial, trial_ref, 'error', stdout, stderr, nil, nil, nil)
        end
      ensure
        transport.send(:current_trial, @slave_ref, nil)
      end

      class InspectingFormatter
        attr_reader :passed, :pending, :failed

        def initialize
          @passed = 0
          @pending = 0
          @failed = 0
          @timeout = false
        end

        def example_passed(example)
          @passed += 1
        end

        def example_pending(example)
          @pending += 1
        end

        def example_failed(example)
          @failed += 1
          if example.exception.is_a?(SoftTimeoutException)
            @timeout = true
          end
        end

        def status
          if @timeout
            'timeout'
          elsif @failed != 0
            'failed'
          elsif @pending != 0
            'pending'
          else
            'passed'
          end
        end
      end
    end
  end
end
