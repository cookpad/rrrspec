module RRRSpec
  module Server
    class MasterAPIHandler
      module NotificatorQuery
        def listen_to_global(ws)
          @global_notificator.listen(ws)
          nil
        end

        def listen_to_taskset(ws, taskset_ref)
          @taskset_notificator.listen(ws, taskset)
          nil
        end

        def close(ws)
          @taskset_notificator.close(ws)
          @global_notificator.close(ws)
          nil
        end

        protected

        def initialize_notificator
          @taskset_notificator = TasksetNotificator.new
          Taskset.after_update(&@taskset_notificator.method(:taskset_updated))
          Task.after_update(&@taskset_notificator.method(:task_updated))
          Trial.after_create(&@taskset_notificator.method(:trial_created))
          Trial.after_update(&@taskset_notificator.method(:trial_updated))
          WorkerLog.after_create(&@taskset_notificator.method(:worker_log_created))
          WorkerLog.after_update(&@taskset_notificator.method(:worker_log_updated))
          Slave.after_create(&@taskset_notificator.method(:slave_created))
          Slave.after_update(&@taskset_notificator.method(:slave_updated))

          @global_notificator = GlobalNotificator.new
          Taskset.after_create(&@global_notificator.method(:taskset_created))
          Taskset.after_update(&@global_notificator.method(:taskset_updated))
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
          tasks = tasks.map do |task_args|
            spec_path, spec_sha1, hard_timeout_sec, soft_timeout_sec = task_args
            taskset.tasks.create(
              spec_path: spec_path,
              spec_sha1: spec_sha1,
              hard_timeout_sec: hard_timeout_sec,
              soft_timeout_sec: soft_timeout_sec,
            )
          end
          tasks.sort_by { |task| [task.hard_timeout_sec, task.soft_timeout_sec] }.reverse_each do |task|
            taskset.queue.enqueue(task)
          end
          Taskset.dispatch
          taskset.to_ref
        end

        def dequeue_task(ws, taskset_ref)
          loop do
            task = TaskQueue.new(taskset_ref[1]).dequeue
            if task
              return [task.to_ref, task.spec_path, task.hard_timeout_sec, task.soft_timeout_sec]
            else
              taskset = Taskset.from_ref(taskset_ref)
              break if taskset.finished?
              taskset.try_finish
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

        def cancel_user_taskset(ws, rsync_name)
          # TODO
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
          Task.from_ref(task_ref).trials.create(slave_id: slave_ref[1]).to_ref
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
        def current_taskset(ws, worker_name, worker_type, taskset_ref)
          Worker.with_name(worker_name).current_taskset_ref = taskset_ref
          Taskset.dispatch unless taskset_ref
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

        def set_rsync_finished_time(ws, worker_log_ref)
          WorkerLog.from_ref(worker_log_ref).finish_rsync
          nil
        end

        def set_setup_finished_time(ws, worker_log_ref)
          WorkerLog.from_ref(worker_log_ref).finish_setup
          nil
        end

        def set_rspec_finished_time(ws, worker_log_ref)
          WorkerLog.from_ref(worker_log_ref).finish_rspec
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

      include NotificatorQuery
      include SpecAverageSecQuery
      include TasksetQuery
      include TaskQuery
      include TrialQuery
      include WorkerQuery
      include WorkerLogQuery
      include SlaveQuery

      def initialize
        initialize_notificator
      end
    end
  end
end
