require 'redis-objects'

module RRRSpec
  module Server
    module Persistence
      module TypeIDReferable
        extend ActiveSupport::Concern

        module ClassMethod
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

      class Taskset < ActiveRecord::Base
        include Redis::Objects
        include JSONConstructor::TasksetJSONConstructor
        include LogFilePersister
        include TypeIDReferable
        has_many :worker_logs
        has_many :slaves
        has_many :tasks
        save_as_file :log, suffix: 'log'
        list :queue

        def self.full
          includes(
            :tasks => [{:trials => [:task, :slave]}, :taskset],
            :slaves => [:trials],
            :worker_logs => [:taskset]
          )
        end

        def enqueue(task)
          queue.push(task.id)
        end

        def reversed_enqueue(task)
          queue.unshift(task.id)
        end

        def dequeue(task)
          Task.find_by_id(queue.shift)
        end

        def fail
          if status.blank? || status == 'running'
            update_attributes(
              status: 'failed',
              finished_at: Time.zone.now,
            )
            clear_queue
          end
        end

        def cancel
          if status.blank? || status == 'running'
            update_attributes(
              status: 'cancel',
              finished_at: Time.zone.now,
            )
            clear_queue
          end
        end

        private

        def clear_queue
          redis.delete(queue.key)
        end
      end

      class Task < ActiveRecord::Base
        include JSONConstructor::TaskJSONConstructor
        include TypeIDReferable
        belongs_to :taskset
        has_many :trials

        def enqueue
          taskset.enqueue(self)
        end

        def reversed_enqueue
          taskset.reversed_enqueue(self)
        end
      end

      class Trial < ActiveRecord::Base
        include JSONConstructor::TrialJSONConstructor
        include LogFilePersister
        include TypeIDReferable
        belongs_to :task
        belongs_to :slave
        save_as_file :stdout, suffix: 'stdout'
        save_as_file :stderr, suffix: 'stderr'

        def finish(finished_at, trial_status, stdout, stderr, passed_count, pending_count, failed_count)
          update_attributes(
            finished_at: finished_at,
            status: trial_status,
            stdout: stdout,
            stderr: stderr,
            passed: passed_count,
            pending: pending_count,
            failed: failed_count,
          )
        end
      end

      class Worker
        OUTDATED_LIMIT_SEC = 30
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

        def current_taskset
          Taskset.from_ref(@current_taskset_ref)
        end

        def current_taskset=(taskset)
          @current_taskset_ref = taskset ? taskset.ref : nil
          @updated_at = Time.zone.now
          taskset
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
        include LogFilePersister
        include TypeIDReferable
        belongs_to :taskset
        save_as_file :log, suffix: 'worker_log'
      end

      class Slave < ActiveRecord::Base
        include JSONConstructor::SlaveJSONConstructor
        include LogFilePersister
        include TypeIDReferable
        has_many :trials
        save_as_file :log, suffix: 'slave_log'
      end
    end
  end
end
