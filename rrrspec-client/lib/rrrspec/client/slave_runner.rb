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
          @timeout = TASKQUEUE_TASK_TIMEOUT
          if @worked_task_keys.include?(task.key)
            @taskset.reversed_enqueue_task(task)
            return
          else
            @worked_task_keys << task.key
          end

          return if task.status.present?
          trial = Trial.create(task, @slave)

          @rspec_runner.reset
          status, outbuf, errbuf = @rspec_runner.setup(File.join(@working_path, task.spec_file))
          unless status
            trial.finish('error', outbuf, errbuf, nil, nil, nil)
            ArbiterQueue.trial(trial)
            return
          end

          soft_timeout_sec, hard_timeout_sec = spec_timeout_sec(task)

          formatter = RedisReportingFormatter.new
          trial.start
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
      end

      class RedisReportingFormatter
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
