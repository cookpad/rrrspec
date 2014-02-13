require 'set'
require 'extreme_timeout'

module RRRSpec
  module Client
    class SlaveRunner
      attr_reader :key

      TASKQUEUE_TASK_TIMEOUT = -1
      TASKQUEUE_ARBITER_TIMEOUT = 20
      TIMEOUT_EXITCODE = 42

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

          if task.estimate_sec == nil
            timeout_sec = @unknown_spec_timeout_sec
          else
            timeout_sec = task.estimate_sec * 2
          end
          timeout_sec = [timeout_sec, @least_timeout_sec].max

          formatter = RedisReportingFormatter.new
          trial.start
          status, outbuf, errbuf = ExtremeTimeout::timeout(
            timeout_sec, TIMEOUT_EXITCODE
          ) do
            @rspec_runner.run(formatter)
          end

          if status
            if formatter.failed != 0
              stat = 'failed'
            elsif formatter.pending != 0
              stat = 'pending'
            else
              stat = 'passed'
            end
            trial.finish(stat, outbuf, errbuf,
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
        end

        def example_passed(example)
          @passed += 1
        end

        def example_pending(example)
          @pending += 1
        end

        def example_failed(example)
          @failed += 1
        end
      end
    end
  end
end
