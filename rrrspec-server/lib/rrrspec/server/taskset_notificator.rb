require 'set'

module RRRSpec
  module Server
    module TasksetEventReceptor
      def taskset_created(taskset)
      end

      def taskset_updated(taskset)
        changes = {}
        taskset.changes.each do |property, diff|
          case property
          when 'status' then changes[:status] = diff.last
          when 'finished_at' then changes[:finished_at] = diff.last
          end
        end
        send_notification(taskset.ref, :taskset_updated, taskset.ref, changes)
      end

      def task_created(task)
      end

      def task_updated(task)
        changes = {}
        task.taskset.changes.each do |property, diff|
          case property
          when 'status' then changes[:status] = diff.last
          end
        end
        send_notification(task.taskset_ref, :task_updated, task.ref, changes)
      end

      def trial_created(trial)
      end

      def trial_updated(trial)
      end

      def worker_log_created(worker_log)
      end

      def worker_log_updated(worker_log)
      end

      def slave_created(slave)
        send_notification(slave.taskset_ref, :slave_created, slave.ref)
      end

      def slave_updated(slave)
        changes = {}
        slave.taskset.changes.each do |property, diff|
          case property
          when 'status' then changes[:status] = diff.last
          end
        end
        send_notification(slave.taskset_ref, :slave_updated, slave.ref, changes)
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

      def send_notification(taskset_ref, method, *params)
        @taskset_to_ws[taskset_ref].each do |ws|
          ws.send(MultiJson.dump({
            method: method, params: params, id: nil,
          }))
        end
      end
    end
  end
end
