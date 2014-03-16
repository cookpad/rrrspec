module RRRSpec
  module Server
    module TasksetEventReceptor
      def taskset_updated(taskset)
        changes = {}
        taskset.changes.each do |property, diff|
          case property
          when 'status' then changes[:status] = diff.last
          when 'finished_at' then changes[:finished_at] = diff.last
          end
        end
        return if changes.empty?
        send_notification(taskset.to_ref, taskset, :taskset_updated,
                          changes)
      end

      def task_updated(task)
        changes = {}
        task.taskset.changes.each do |property, diff|
          case property
          when 'status' then changes[:status] = diff.last
          end
        end
        return if changes.empty?
        send_notification(task.taskset_ref, task, :task_updated,
                          changes)
      end

      def trial_created(trial)
        send_notification(trial.task.taskset_ref, trial, :trial_created,
                          trial.task_ref, trial.slave_ref, trial.created_at)
      end

      def trial_updated(trial)
        send_notification(trial.task.taskset_ref, trial, :trial_updated,
                          trial.task_ref, trial.finished_at, trial.status, trial.passed, trial.pending, trial.failed)
      end

      def worker_log_created(worker_log)
        send_notification(worker_log.taskset_ref, worker_log, :worker_log_created,
                          worker_log.worker_name)
      end

      def worker_log_updated(worker_log)
        changes = {}
        task.taskset.changes.each do |property, diff|
          case property
          when 'rsync_finished_at' then changes[:rsync_finished_at] = diff.last
          when 'setup_finished_at' then changes[:setup_finished_at] = diff.last
          when 'finished_at' then changes[:finished_at] = diff.last
          end
        end
        return if changes.empty?
        send_notification(worker_log.taskset_ref, worker_log, :worker_log_updated,
                          changes)
      end

      def slave_created(slave)
        send_notification(slave.taskset_ref, slave, :slave_created,
                          slave.name)
      end

      def slave_updated(slave)
        changes = {}
        slave.taskset.changes.each do |property, diff|
          case property
          when 'status' then changes[:status] = diff.last
          end
        end
        send_notification(slave.taskset_ref, slave, :slave_updated,
                          changes)
      end
    end

    class TasksetNotificator
      include TasksetEventReceptor

      def initialize
        @transport_to_taskset = Hash.new { |h,k| h[k] = Set.new }
        @taskset_to_transport = Hash.new { |h,k| h[k] = Set.new }
      end

      def listen(transport, taskset_ref)
        @transport_to_taskset[transport].add(taskset_ref)
        @taskset_to_transport[taskset_ref].add(transport)
      end

      def close(transport)
        @transport_to_taskset[transport].each do |taskset_ref|
          @taskset_to_transport[taskset_ref].delete(transport)
        end
        @transport_to_taskset.delete(transport)
      end

      private

      def send_notification(taskset_ref, object, method, *params)
        params = [object.updated_at, object.to_ref] + params
        @taskset_to_transport[taskset_ref].each do |transport|
          transport.send(method, *params)
        end
      end
    end

    module GlobalEventReceptor
      def taskset_created(taskset)
        send_notification(taskset, :taskset_craeted,
                          taskset.created_at, taskset.rsync_name, taskset.worker_type, taskset.taskset_class)
      end

      def taskset_updated(taskset)
        changes = {}
        taskset.changes.each do |property, diff|
          case property
          when 'status' then changes[:status] = diff.last
          when 'finished_at' then changes[:finished_at] = diff.last
          end
        end
        return if changes.empty?
        send_notification(taskset, :taskset_updated, changes)
      end
    end

    class GlobalNotificator
      include GlobalEventReceptor

      def initialize
        @transports = Set.new
      end

      def listen(transport)
        @transports.add(transport)
      end

      def close(transport)
        @transports.delete(transport)
      end

      private

      def send_notification(object, method, *params)
        params = [object.updated_at, object.to_ref] + params
        @transports.each do |transport|
          transport.send(method, *params)
        end
      end
    end
  end
end
