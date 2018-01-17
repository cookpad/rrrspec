require 'set'
require 'extreme_timeout'
require 'timeout'
require 'rspec/core/formatters'

module RRRSpec
  module Client
    class SlaveRunner
      attr_reader :key

      TASKQUEUE_TASK_TIMEOUT = -1
      TASKQUEUE_ARBITER_TIMEOUT = 20
      TIMEOUT_EXITCODE = 42
      class SoftTimeoutException < Exception; end
      class OutsideExamplesError < StandardError; end

      def initialize(slave, working_dir, taskset_key)
        @slave = slave
        @taskset = Taskset.new(taskset_key)
        @timeout = TASKQUEUE_TASK_TIMEOUT
        @rspec_runner = RSpecRunner.new
        @working_path = File.join(working_dir, @taskset.rsync_name)
        @unknown_spec_timeout_sec = @taskset.unknown_spec_timeout_sec
        @least_timeout_sec = @taskset.least_timeout_sec
        @worked_task_keys = Set.new
      end

      def work_loop
        loop { work }
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

      def work
        task = @taskset.dequeue_task(@timeout)
        unless task
          @timeout = TASKQUEUE_ARBITER_TIMEOUT
          ArbiterQueue.check(@taskset)
        else
          if @worked_task_keys.include?(task.key)
            @taskset.reversed_enqueue_task(task)
            return
          else
            @worked_task_keys << task.key
          end
          return if task.status.present?

          @timeout = TASKQUEUE_TASK_TIMEOUT
          trial = Trial.create(task, @slave)

          @rspec_runner.reset
          $0 = "rrrspec slave[#{ENV['SLAVE_NUMBER']}]: setting up #{task.spec_file}"
          status, outbuf, errbuf = @rspec_runner.setup(File.join(@working_path, task.spec_file))
          unless status
            trial.finish('error', outbuf, errbuf, nil, nil, nil)
            ArbiterQueue.trial(trial)
            return
          end

          soft_timeout_sec, hard_timeout_sec = spec_timeout_sec(task)

          formatter = RedisReportingFormatter
          trial.start
          $0 = "rrrspec slave[#{ENV['SLAVE_NUMBER']}]: running #{task.spec_file}"
          status, outbuf, errbuf = ExtremeTimeout::timeout(
            hard_timeout_sec, TIMEOUT_EXITCODE
          ) do
            Timeout::timeout(soft_timeout_sec, SoftTimeoutException) do
              @rspec_runner.run(formatter)
            end
          end
          if status
            trial.finish(formatter.status, outbuf, errbuf,
                         formatter.passed, formatter.pending, formatter.failed)
          else
            trial.finish('error', outbuf, errbuf, nil, nil, nil)
          end

          ArbiterQueue.trial(trial)
        end
      ensure
        $0 = "rrrspec slave[#{ENV['SLAVE_NUMBER']}]"
      end

      class RedisReportingFormatter
        RSpec::Core::Formatters.register(
          self, :example_passed, :example_pending, :example_failed, :dump_summary
        )

        def initialize(_output)
          self.class.reset
        end

        def example_passed(_notification)
          self.class.example_passed
        end

        def example_pending(_notification)
          self.class.example_pending
        end

        def example_failed(notification)
          self.class.example_failed(notification)
        end

        def dump_summary(notification)
          # RSpec skips all examples when error outside examples occurred
          # So we will raise error and make current taskset failure
          if notification.errors_outside_of_examples_count > 0
            raise OutsideExamplesError
          end
        end

        module ClassMethods
          attr_reader :passed, :pending, :failed

          def reset
            @passed = 0
            @pending = 0
            @failed = 0
            @timeout = false
          end

          def example_passed
            @passed += 1
          end

          def example_pending
            @pending += 1
          end

          def example_failed(notification)
            @failed += 1
            if notification.exception.is_a?(SoftTimeoutException)
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
        extend ClassMethods
      end
    end
  end
end
