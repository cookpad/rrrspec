require 'activerecord-import'
require 'active_support/inflector'
ActiveSupport::Inflector::Inflections.instance.singular('Slaves', 'Slave')
ActiveSupport::Inflector::Inflections.instance.singular('slaves', 'slave')
ActiveRecord::Base.include_root_in_json = false
ActiveRecord::Base.default_timezone = :utc

module RRRSpec
  module Server
    module Persister
      SLAVE_EXIT_WAIT_TIME = 15
      PERSISTED_RESIDUE_SEC = 60

      module_function

      def work_loop
        loop { work }
      end

      def work
        taskset = PersisterQueue.dequeue
        ActiveRecord::Base.connection_pool.with_connection do
          return if Persistence::Taskset.where(key: taskset.key).exists?
        end

        sleep SLAVE_EXIT_WAIT_TIME

        ActiveRecord::Base.connection_pool.with_connection do
          persist(taskset)
          taskset.expire(PERSISTED_RESIDUE_SEC)
        end

        StatisticsUpdaterQueue.enqueue(taskset)
      rescue
        RRRSpec.logger.error($!)
      end

      private
      module_function

      def persist(taskset)
        taskset_finished_at = taskset.finished_at
        return if taskset_finished_at.blank?

        RRRSpec.logger.debug("Persisting taskset #{taskset.key}")
        start = Time.now

        p_taskset = ActiveRecord::Base.transaction do
          h = taskset.to_h
          h.delete('tasks')
          h.delete('slaves')
          h.delete('worker_logs')
          Persistence::Taskset.create(h)
        end

        ActiveRecord::Base.transaction do
          p_slaves = taskset.slaves.map do |slave|
            h = slave.to_h
            h.delete('trials')
            p_slave = Persistence::Slave.new(h)
            p_slave.taskset_id = p_taskset.id
            p_slave
          end
          Persistence::Slave.import(p_slaves)
          p_slaves.each { |p_slave| p_slave.run_callbacks(:save) {} }
        end

        ActiveRecord::Base.transaction do
          p_tasks = taskset.tasks.map do |task|
            h = task.to_h
            h.delete('taskset')
            h.delete('trials')
            p_task = Persistence::Task.new(h)
            p_task.taskset_id = p_taskset
            p_task
          end
          Persistence::Task.import(p_tasks)
          p_tasks.each { |p_task| p_task.run_callbacks(:save) {} }
        end

        p_slaves = {}
        p_taskset.slaves.each do |p_slave|
          p_slaves[p_slave.key] = p_slave
        end

        ActiveRecord::Base.transaction do
          p_trials = []
          p_taskset.tasks.each do |p_task|
            Task.new(p_task.key).trials.each do |trial|
              h = trial.to_h
              next if h['finished_at'].blank? || h['finished_at'] > taskset_finished_at
              slave_key = h.delete('slave')['key']
              h.delete('task')
              p_trial = Persistence::Trial.new(h)
              p_trial.task_id = p_task
              p_trial.slave_id = p_slaves[slave_key]

              p_trials << p_trial
            end
          end
          Persistence::Trial.import(p_trials)
          p_trials.each { |p_trial| p_trial.run_callbacks(:save) {} }
        end

        ActiveRecord::Base.transaction do
          p_worker_logs = taskset.worker_logs.map do |worker_log|
            h = worker_log.to_h
            h['worker_key'] = h['worker']['key']
            h.delete('worker')
            h.delete('taskset')
            p_worker_log = Persistence::WorkerLog.new(h)
            p_worker_log.taskset_id = p_taskset
            p_worker_log
          end
          Persistence::WorkerLog.import(p_worker_logs)
          p_worker_logs.each { |p_worker_log| p_worker_log.run_callbacks(:save) {} }
        end

        RRRSpec.logger.info("Taskset #{taskset.key} persisted (#{Time.now - start} seconds taken)")
      end
    end
  end
end
