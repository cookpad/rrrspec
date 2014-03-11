module RRRSpec
  module Server
    module NotificatorQuery
      def listen_to_global(ws)
        @global_notificator.listen(ws)
        nil
      end

      def listen_to_taskset(ws, taskset_ref)
        @taskset_notificator.listen(ws, taskset)
        nil
      end
    end

    module SpecAverageSecQuery
      def query_spec_average_sec(ws, spec_sha1)
        # TODO
      end
    end

    module TasksetQuery
      def create_taskset(ws, rsync_name, setup_command, slave_command, worker_type, taskset_class, max_workers, max_trials, tasks)
        taskset = Taskset.create(
          rsync_name: rsync_name,
          setup_command: setup_command,
          slave_command: slave_command,
          worker_type: worker_type,
          max_workers: max_workers,
          max_trials: max_trials,
          taskset_class: taskset_class,
        )
        tasks.each do |task_args|
          spec_path, spec_sha1, hard_timeout_sec, soft_timeout_sec = task_args
          task = taskset.tasks.create(
            spec_path: spec_path,
            spec_sha1: spec_sha1,
            hard_timeout_sec: hard_timeout_sec,
            soft_timeout_sec: soft_timeout_sec,
          )
          taskset.queue.enqueue(task)
        end
        Taskset.dispatch
        taskset.to_ref
      end

      def dequeue_task(ws, taskset_ref)
        # TODO: It is possible that other threads take a task that is enqueued
        # in this thread.
        2.times do |count|
          task = TaskQueue.new(taskset_ref[1]).dequeue
          if task
            return [task.to_ref, task.spec_path, task.hard_timeout_sec, task.soft_timeout_sec]
          elsif count == 0
            Taskset.from_ref(taskset_ref).try_finish
          end
        end
        nil
      end

      def try_finish_taskset(ws, taskset_ref)
        Taskset.from_ref(taskset_ref).try_finish
        nil
      end

      def fail_taskset(ws, taskset_ref)
        Taskset.from_ref(taskset_ref).fail
        nil
      end

      def cancel_taskset(ws, taskset_ref)
        Taskset.from_ref(taskset_ref).cancel
        nil
      end

      def query_taskset_status(ws, taskset_ref)
        Taskset.from_ref(taskset_ref).status
      end
    end

    module TaskQuery
      def reversed_enqueue_task(ws, task_ref)
        Task.from_ref(task_ref).reversed_enqueue
        nil
      end
    end

    module TrialQuery
      def create_trial(ws, task_ref, slave_ref)
        Task.from_ref(task_ref).trials.create(
          slave_id: slave_ref[1],
        ).to_ref
      end

      def start_trial(ws, trial_ref)
        Trial.from_ref(trial_ref).update_attributes(started_at: Time.zone.now)
        nil
      end

      def finish_trial(ws, trial_ref, trial_status, stdout, stderr, passed_count, pending_count, failed_count)
        Trial.from_ref(trial_ref).finish(trial_status, stdout, stderr, passed_count, pending_count, failed_count)
        nil
      end
    end

    module WorkerQuery
      def current_taskset(ws, worker_name, taskset_ref)
        Worker.with_name(worker_name).current_taskset_ref = taskset_ref
        nil
      end
    end

    module WorkerLogQuery
      def create_worker_log(ws, worker_name, taskset_ref)
        WorkerLog.create(worker_name: worker_name, taskset_id: taskset_ref[1]).to_ref
      end

      def append_worker_log_log(ws, worker_log_ref, log)
        WorkerLog.from_ref(worker_log_ref).log.append(log)
        nil
      end

      def set_rsync_finished_time(ws, worker_log_ref, finished_at)
        WorkerLog.from_ref(worker_log_ref).update_attributes(rsync_finished_at: finished_at)
        nil
      end

      def set_setup_finished_time(ws, worker_log_ref, finished_at)
        WorkerLog.from_ref(worker_log_ref).update_attributes(setup_finished_at: finished_at)
        nil
      end

      def finish_worker_log(ws, worker_log_ref)
        WorkerLog.from_ref(worker_log_ref).finish
        nil
      end
    end

    module SlaveQuery
      def create_slave(ws, slave_name, taskset_ref)
        Slave.create(name: slave_name, taskset_id: taskset_ref[1]).to_ref
      end

      def current_trial(ws, slave_ref, trial_ref)
        # TODO
      end

      def finish_slave(ws, slave_ref, status)
        Slave.from_ref(slave_ref).finish(status)
        nil
      end

      def force_finish_slave(ws, slave_name, status)
        # TODO
      end
    end

    class MasterApp
      include SpecAverageSecQuery
      include TasksetQuery
      include TaskQuery
      include TrialQuery
      include WorkerQuery
      include WorkerLogQuery
      include SlaveQuery

      def initialize
        @taskset_notificator = TasksetNotificator.new
        @global_notificator = GlobalNotificator.new
      end

      # close handles the websocket close events
      def close(ws)
        @taskset_notificator.close(ws)
        @global_notificator.close(ws)
        nil
      end
    end
  end
end
