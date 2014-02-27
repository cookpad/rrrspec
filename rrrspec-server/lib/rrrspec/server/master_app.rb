module RRRSpec
  module Server
    module SpecAverageSecQuery
      def query_spec_average_sec(ws, spec_sha1)
      end
    end

    module TasksetQuery
      def create_taskset(ws, rsync_name, setup_command, slave_command, worker_type, taskset_class, max_workers, max_trials, tasks)
      end

      def dequeue_task(ws, taskset_ref)
      end

      def try_finish_taskset(ws, taskset_ref)
      end

      def fail_taskset(ws, taskset_ref)
      end

      def query_taskset_status(ws, taskset_ref)
      end

      def listen_to_taskset(ws, taskset_ref)
      end
    end

    module TaskQuery
      def reversed_enqueue_task(ws, task_ref)
      end
    end

    module TrialQuery
      def create_trial(ws, task_ref)
      end

      def finish_trial(ws, trial_ref, trial_status, stdout, stderr, passed_count, pending_count, failed_count)
      end
    end

    module WorkerQuery
      def current_taskset(ws, worker_ref, taskset_ref)
      end
    end

    module WorkerLogQuery
      def create_worker_log(ws, worker_name)
      end

      def append_worker_log_log(ws, worker_ref, log)
      end

      def finish_worker_log(ws, worker_ref)
      end
    end

    module SlaveQuery
      def create_slave(ws, slave_name)
      end

      def append_slave_log(ws, slave_ref, log)
      end

      def current_trial(ws, slave_ref, trial_ref)
      end

      def finish_slave(ws, slave_ref)
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

      def close(ws)
        @taskset_notificator.close(ws)
        @global_notificator.close(ws)
      end
    end
  end
end
