module RRRSpec
  module Server
    module TypeIDReferable
      extend ActiveSupport::Concern

      module ClassMethods
        def from_ref(ref)
          label, i = ref
          raise ArgumentError unless label == self.name.to_s
          find_by_id(i)
        end
      end

      def to_ref
        [self.class.name.to_s, id]
      end
    end

    class TaskQueue
      def initialize(taskset_id)
        @key = ['rrrspec', 'Taskset', taskset_id.to_s, 'queue'].join(':')
      end

      def enqueue(task)
        RRRSpec::Server.redis.rpush(@key, task.id)
      end

      def reversed_enqueue(task)
        RRRSpec::Server.redis.lpush(@key, task.id)
      end

      def size
        RRRSpec::Server.redis.llen(@key)
      end

      def empty?
        size == 0
      end

      def dequeue
        task_id = RRRSpec::Server.redis.lpop(@key)
        task_id ? Task.find_by_id(task_id) : nil
      end

      def clear
        RRRSpec::Server.redis.del(@key)
      end
    end

    class Taskset < ActiveRecord::Base
      include JSONConstructor::TasksetJSONConstructor
      include LargeStringAttribute
      include TypeIDReferable
      has_many :worker_logs
      has_many :slaves
      has_many :tasks
      large_string :log

      def self.dispatch
        # TODO
      end

      def self.full
        includes(
          :tasks => [{:trials => [:task, :slave]}, :taskset],
          :slaves => [:trials],
          :worker_logs => [:taskset]
        )
      end

      def queue
        @queue ||= TaskQueue.new(id)
      end

      def fail
        finish('failed')
      end

      def cancel
        finish('cancelled')
      end

      def finished?
        !(status.blank? || status == 'running')
      end

      def finish(status)
        unless finished?
          update_attributes(status: status, finished_at: Time.zone.now)
          queue.clear
        end
      end

      def try_finish
        return if finished?

        unfinished_tasks = tasks.where(status: nil).includes(:trials).select do |task|
          !task.try_finish(max_trials)
        end

        if unfinished_tasks.empty?
          finish(tasks.where(status: 'failed').count > 0 ? 'failed' : 'succeeded')
        elsif queue.empty?
          requeue_speculative(unfinished_tasks)
        end
      end

      def requeue_speculative(tasks)
        groups = tasks.group_by { |task| task.trials.size }
        groups[groups.keys.min].sample.enqueue
      end
    end

    class Task < ActiveRecord::Base
      include JSONConstructor::TaskJSONConstructor
      include TypeIDReferable
      belongs_to :taskset
      has_many :trials

      def enqueue
        TaskQueue.new(taskset_id).enqueue(self)
      end

      def reversed_enqueue
        TaskQueue.new(taskset_id).reversed_enqueue(self)
      end

      def try_finish(max_trials=taskset.max_trials)
        return true if status.present?

        statuses = trials.pluck(:status)
        case
        when statuses.include?('passed')
          update_attributes(status: 'passed')
          true
        when statuses.include?('pending')
          update_attributes(status: 'pending')
          true
        when statuses.include?(nil)
          false
        else
          faileds = statuses.count { |status| ['failed', 'error', 'timeout'].include?(status) }
          if faileds >= max_trials
            update_attributes(status: 'failed')
            true
          else
            reversed_enqueue
            false
          end
        end
      end

      def taskset_ref
        [:taskset, taskset_id]
      end
    end

    class Trial < ActiveRecord::Base
      include JSONConstructor::TrialJSONConstructor
      include LargeStringAttribute
      include TypeIDReferable
      belongs_to :task
      belongs_to :slave
      large_string :stdout
      large_string :stderr

      def finish(trial_status, stdout, stderr, passed_count, pending_count, failed_count)
        update_attributes(
          finished_at: Time.zone.now,
          status: trial_status,
          stdout: stdout,
          stderr: stderr,
          passed: passed_count,
          pending: pending_count,
          failed: failed_count,
        )
        task.try_finish
      end

      def task_ref
        [:task, task_id]
      end

      def slave_ref
        [:slave, slave_id]
      end
    end

    # TODO: Move to Redis
    class Worker
      @@workers = Hash.new

      def self.all
        revoke_outdated
        @@workers.values
      end

      def self.revoke_outdated
        limit = Time.zone.now - OUTDATED_LIMIT_SEC.second
        @@workers.values.each do |worker|
          if worker.updated_at && worker.updated_at < limit
            @@workers.delete(worker.name)
          end
        end
      end

      def self.with_name(name)
        @@workers[name] ||= Worker.new(name)
      end

      attr_reader :name, :updated_at

      def current_taskset_ref
        @current_taskset_ref
      end

      def current_taskset_ref=(taskset_ref)
        @current_taskset_ref = taskset_ref ? taskset_ref : nil
        @updated_at = Time.zone.now
        taskset_ref
      end

      private

      def initialize(name)
        @name = name
        @current_taskset_ref = nil
        @updated_at = nil
      end
    end

    class WorkerLog < ActiveRecord::Base
      include JSONConstructor::WorkerLogJSONConstructor
      include LargeStringAttribute
      include TypeIDReferable
      belongs_to :taskset
      large_string :log

      def finish_rsync
        update_attributes(rsync_finished_at: Time.zone.now)
      end

      def finish_setup
        update_attributes(setup_finished_at: Time.zone.now)
      end

      def finish_rspec
        update_attributes(rspec_finished_at: Time.zone.now)
        log.flush
      end

      def taskset_ref
        [:taskset, taskset_id]
      end
    end

    class Slave < ActiveRecord::Base
      include JSONConstructor::SlaveJSONConstructor
      include TypeIDReferable
      belongs_to :taskset
      has_many :trials

      def finish(status)
        update_attributes(status: status, finished_at: Time.zone.now)
        log.flush
      end

      def taskset_ref
        [:taskset, taskset_id]
      end
    end
  end
end
