module RRRSpec
  module Server
    class Dispatcher
      def self.work
        assigned = Hash.new { |hash,key| hash[key] = [] }
        unemployed = Hash.new { |hash,key| hash[key] = [] }
        Worker.list.each do |worker|
          unless worker.exist?
            worker.evict
          else
            taskset = worker.current_taskset
            if taskset
              assigned[taskset.key] << worker
            else
              unemployed[worker.worker_type] << worker
            end
          end
        end

        ActiveTaskset.list.each do |taskset|
          should_mark_running = false
          case taskset.status
          when 'succeeded', 'cancelled', 'failed'
            next
          when nil
            should_mark_running = true
          end

          # Cache the values
          max_workers = taskset.max_workers
          worker_type = taskset.worker_type
          while max_workers > assigned[taskset.key].size
            break if unemployed[worker_type].empty?
            worker = unemployed[worker_type].pop
            if should_mark_running
              taskset.update_status('running')
              should_mark_running = false
            end
            worker.enqueue_taskset(taskset)
            assigned[taskset.key] << worker
          end
        end
      end

      def self.work_loop
        loop do
          DispatcherQueue.wait
          work
        end
      end
    end
  end
end
