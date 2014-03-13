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
        @ws_to_taskset = Hash.new { |h,k| h[k] = Set.new }
        @taskset_to_ws = Hash.new { |h,k| h[k] = Set.new }
      end

      def listen(ws, taskset_ref)
        @ws_to_taskset[ws].add(taskset_ref)
        @taskset_to_ws[taskset_ref].add(ws)
      end

      def close(ws)
        @ws_to_taskset[ws].each do |taskset_ref|
          @taskset_to_ws[taskset_ref].delete(ws)
        end
        @ws_to_taskset.delete(ws)
      end

      private

      def send_notification(taskset_ref, object, method, *params)
        params = [object.updated_at, object.to_ref] + params
        @taskset_to_ws[taskset_ref].each do |ws|
          ws.send(MultiJson.dump({
            method: method, params: params, id: nil,
          }))
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
        @wsockets = Set.new
      end

      def listen(ws)
        @wsockets.add(ws)
      end

      def close(ws)
        @wsockets.delete(ws)
      end

      private

      def send_notification(object, method, *params)
        params = [object.updated_at, object.to_ref] + params
        @wsockets.each do |ws|
          ws.send(MultiJson.dump({
            method: method, params: params, id: nil,
          }))
        end
      end
    end
  end
end
