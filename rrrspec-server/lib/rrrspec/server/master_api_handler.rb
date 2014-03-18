module RRRSpec
  module Server
    class MasterAPIHandler
      module NotificatorQuery
        def listen_to_global(transport)
          GlobalNotificator.instance.listen(transport)
          nil
        end

        def listen_to_taskset(transport, taskset_ref)
          TasksetNotificator.instance.listen(transport, taskset_ref)
          nil
        end

        def close(transport)
          TasksetNotificator.instance.close(transport)
          GlobalNotificator.instance.close(transport)
          nil
        end

        protected

        def initialize_notificator
        end
      end

      module SpecAverageSecQuery
        def query_spec_average_sec(transport, taskset_class, spec_sha1)
          Task.average(taskset_class, spec_sha1)
        end
      end

      module TasksetQuery
        def create_taskset(transport, rsync_name, setup_command, slave_command, worker_type, taskset_class, max_workers, max_trials, tasks)
          raise "the user is running a taskset" if Taskset.is_running?(rsync_name)
          taskset = Taskset.create(
            rsync_name: rsync_name,
            setup_command: setup_command,
            slave_command: slave_command,
            worker_type: worker_type,
            max_workers: max_workers,
            max_trials: max_trials,
            taskset_class: taskset_class,
            status: 'rsync_waiting',
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
          taskset.to_ref
        end

        def dispatch_taskset(transport, taskset_ref)
          taskset = Taskset.from_ref(taskset_ref)
          taskset.start_working
          Taskset.dispatch
          nil
        end

        def dequeue_task(transport, taskset_ref)
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

        def try_finish_taskset(transport, taskset_ref)
          Taskset.from_ref(taskset_ref).try_finish
          nil
        end

        def fail_taskset(transport, taskset_ref)
          Taskset.from_ref(taskset_ref).fail
          nil
        end

        def cancel_taskset(transport, taskset_ref)
          Taskset.from_ref(taskset_ref).cancel
          nil
        end

        def cancel_user_taskset(transport, rsync_name)
          Taskset.users(rsync_name).using.each do |taskset|
            taskset.cancel
          end
          nil
        end

        def query_taskset_status(transport, taskset_ref)
          Taskset.from_ref(taskset_ref).status
        end
      end

      module TaskQuery
        def reversed_enqueue_task(transport, task_ref)
          Task.from_ref(task_ref).reversed_enqueue
          nil
        end
      end

      module TrialQuery
        def create_trial(transport, task_ref, slave_ref)
          Task.from_ref(task_ref).trials.create(slave_id: slave_ref[1]).to_ref
        end

        def start_trial(transport, trial_ref)
          Trial.from_ref(trial_ref).update_attributes(started_at: Time.zone.now)
          nil
        end

        def finish_trial(transport, trial_ref, trial_status, stdout, stderr, passed_count, pending_count, failed_count)
          Trial.from_ref(trial_ref).finish(trial_status, stdout, stderr, passed_count, pending_count, failed_count)
          nil
        end
      end

      module WorkerQuery
        def current_taskset(transport, worker_name, worker_type, taskset_ref)
          Worker.with_name(worker_name).current_taskset_ref = taskset_ref
          Taskset.dispatch unless taskset_ref
          nil
        end
      end

      module WorkerLogQuery
        def create_worker_log(transport, worker_name, taskset_ref)
          WorkerLog.create(worker_name: worker_name, taskset_id: taskset_ref[1]).to_ref
        end

        def append_worker_log_log(transport, worker_log_ref, log)
          WorkerLog.from_ref(worker_log_ref).log.append(log)
          nil
        end

        def set_rsync_finished_time(transport, worker_log_ref)
          WorkerLog.from_ref(worker_log_ref).finish_rsync
          nil
        end

        def set_setup_finished_time(transport, worker_log_ref)
          WorkerLog.from_ref(worker_log_ref).finish_setup
          nil
        end

        def set_rspec_finished_time(transport, worker_log_ref)
          WorkerLog.from_ref(worker_log_ref).finish_rspec
          nil
        end
      end

      module SlaveQuery
        def create_slave(transport, slave_name, taskset_ref)
          Slave.create(name: slave_name, taskset_id: taskset_ref[1]).to_ref
        end

        def current_trial(transport, slave_ref, trial_ref)
          # TODO
        end

        def finish_slave(transport, slave_ref, status)
          Slave.from_ref(slave_ref).finish(status)
          nil
        end

        def force_finish_slave(transport, slave_name, status)
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

      def open(transport)
      end
    end
  end
end
