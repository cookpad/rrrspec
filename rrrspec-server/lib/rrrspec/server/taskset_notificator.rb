require 'set'

module RRRSpec
  module Server
    class TasksetNotificator
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

      def taskset_changed(taskset, type)
        return unless type == :update

        changes = {}
        taskset.changes.each do |property, diff|
          case property
          when 'status' then changes[:status] = diff.last
          when 'finished_at' then changes[:finished_at] = diff.last
          end
        end
        send_notification(taskset_ref, :taskset_updated, taskset.ref, changes)
      end

      def task_changed(task, type)
        return unless type == :update

        changes = {}
        task.taskset.changes.each do |property, diff|
          case property
          when 'status' then changes[:status] = diff.last
          end
        end
        send_notification(taskset_ref, :task_updated, task.ref, changes)
      end

      def worker_log_changed(worker_log, type)
      end

      def slave_changed(slave, type)
        if type == :update
          changes = {}
          slave.taskset.changes.each do |property, diff|
            case property
            when 'status' then changes[:status] = diff.last
            end
          end
          send_notification(taskset_ref, :slave_updated, slave.ref, changes)
        elsif type == :create
          send_notification(taskset_ref, :slave_created, slave.ref)
        end
      end

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
