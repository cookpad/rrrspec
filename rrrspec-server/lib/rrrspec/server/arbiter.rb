module RRRSpec
  module Server
    module Arbiter
      module_function

      def work_loop
        loop { work }
      end

      def work
        command, arg = ArbiterQueue.dequeue
        case command
        when 'cancel'
          cancel(arg)
        when 'check'
          check(arg)
        when 'fail'
          fail(arg)
        when 'trial'
          trial(arg)
        end
      end

      private
      module_function

      def cancel(taskset)
        logger = TimedLogger.new(taskset)
        logger.write("Cancel requested")

        if [nil, 'running'].include?(taskset.status)
          taskset.update_status('cancelled')
          taskset.set_finished_time
          taskset.clear_queue
        end
        PersisterQueue.enqueue(taskset)
        ActiveTaskset.remove(taskset)
      end

      def check(taskset)
        logger = TimedLogger.new(taskset)
        logger.write("Check requested")

        unless taskset.status == 'running'
          PersisterQueue.enqueue(taskset)
          ActiveTaskset.remove(taskset)
          return
        end

        tasks_left = taskset.tasks_left
        tasks_left.each do |task|
          check_task(logger, taskset, task)
        end

        tasks_left = taskset.tasks_left
        if tasks_left.empty?
          if taskset.failed_count == 0
            taskset.update_status('succeeded')
          else
            taskset.update_status('failed')
          end
          taskset.set_finished_time
          PersisterQueue.enqueue(taskset)
          ActiveTaskset.remove(taskset)
        elsif taskset.queue_empty?
          requeue_speculative(logger, taskset, tasks_left)
        end
      end

      def check_task(logger, taskset, task)
        running_trial = []
        passed_trial = []
        pending_trial = []
        failed_trial = []
        trials = task.trials
        trials.each do |trial|
          case trial.status
          when nil, ''
            if trial.slave.exist?
              running_trial << trial
            else
              trial.finish('error', '', 'Failed by Arbiter', nil, nil, nil)
              failed_trial << trial
            end
          when 'passed'
            passed_trial << trial
          when 'pending'
            pending_trial << trial
          when 'failed', 'error', 'timeout'
            failed_trial << trial
          end
        end
        case
        when !passed_trial.empty?
          task.update_status('passed')
          taskset.incr_succeeded_count
          taskset.finish_task(task)
        when !pending_trial.empty?
          task.update_status('pending')
          taskset.incr_succeeded_count
          taskset.finish_task(task)
        when !running_trial.empty?
          # Do nothing
        when failed_trial.size >= taskset.max_trials
          logger.write("Mark failed #{task.key}")
          task.update_status('failed')
          taskset.incr_failed_count
          taskset.finish_task(task)
        end
      end

      def requeue_speculative(logger, taskset, tasks_left)
        running_tasks = Hash.new { |hash,key| hash[key] = [] }
        not_running_tasks = []
        tasks_left.each do |task|
          trials = task.trials
          if trials.any? { |trial| trial.status.blank? }
            running_tasks[trials.size] << task
          else
            not_running_tasks << task
          end
        end

        if not_running_tasks.empty?
          task = running_tasks[running_tasks.keys.min].sample
          logger.write("Speculatively enqueue the task #{task.key}")
          taskset.enqueue_task(task)
        else
          task = not_running_tasks.sample
          logger.write("Enqueue the task #{task.key}")
          taskset.enqueue_task(task)
        end
      end

      def fail(taskset)
        logger = TimedLogger.new(taskset)
        logger.write("Fail requested")

        if [nil, 'running'].include?(taskset.status)
          taskset.update_status('failed')
          taskset.set_finished_time
          taskset.clear_queue
        end
        PersisterQueue.enqueue(taskset)
        ActiveTaskset.remove(taskset)
      end

      def trial(trial)
        task = trial.task
        return if task.status.present?
        taskset = task.taskset
        logger = TimedLogger.new(taskset)

        if trial.status == nil
          trial.finish('error', '', 'Failed by Arbiter', nil, nil, nil)
        end

        case trial.status
        when 'passed'
          task.update_status('passed')
          taskset.incr_succeeded_count
          taskset.finish_task(task)
        when 'pending'
          task.update_status('pending')
          taskset.incr_succeeded_count
          taskset.finish_task(task)
        when 'failed', 'error', 'timeout'
          trials = task.trials
          finished_trials = []
          trials.each do |trial|
            finished_trials << trial unless [nil, ''].include?(trial.status)
          end
          if finished_trials.size >= taskset.max_trials
            task.update_status('failed')
            taskset.incr_failed_count
            taskset.finish_task(task)
          elsif trials.size < taskset.max_trials
            task.update_status(nil)
            logger.write("Enqueue the task #{task.key}")
            taskset.reversed_enqueue_task(task)
          end
        end
      end
    end
  end
end
