require 'zlib'
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
          if RRRSpec.configuration.json_cache_path
            create_api_cache(taskset, RRRSpec.configuration.json_cache_path)
          end
          taskset.expire(PERSISTED_RESIDUE_SEC)
          update_estimate_sec(taskset)
        end
      rescue
        RRRSpec.logger.error($!)
      end

      private
      module_function

      def persist(taskset)
        taskset_finished_at = taskset.finished_at
        return if taskset_finished_at.blank?

        p_taskset = ActiveRecord::Base.transaction do
          h = taskset.to_h
          h.delete('tasks')
          h.delete('slaves')
          h.delete('worker_logs')
          begin
            Persistence::Taskset.create(h)
          rescue ActiveRecord::StatementInvalid, Mysql2::Error => e
            if e.message && e.message.match(/Data too long for column '(.+?)'/)
              column = $1
              RRRSpec.logger.error "column too long!!!"
              RRRSpec.logger.error h.delete(column.to_sym) || ''
              RRRSpec.logger.error h.delete(column) || ''
              retry
            else
              raise e
            end
          end
        end

        ActiveRecord::Base.transaction do
          p_slaves = taskset.slaves.map do |slave|
            h = slave.to_h
            h.delete('trials')
            p_slave = Persistence::Slave.new(h)
            p_slave.taskset_id = p_taskset.id
            if 65000 < p_slave.log.size
              p_slave.log = "#{p_slave.log.mb_chars.limit(65000)}...(too long, truncated)"
            end
            save_log_file(slave.key, 'slave_log', slave.log)
            p_slave
          end
          Persistence::Slave.import(p_slaves)
        end

        ActiveRecord::Base.transaction do
          Persistence::Task.import(taskset.tasks.map do |task|
            h = task.to_h
            h.delete('taskset')
            h.delete('trials')
            p_task = Persistence::Task.new(h)
            p_task.taskset_id = p_taskset
            p_task
          end)
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
              if 65000 < p_trial.stderr.size
                p_trial.stderr = "#{p_trial.stderr.mb_chars.limit(65000)}...(too long, truncated)"
              end
              save_log_file(trial.key, 'stdout', trial.stdout)
              if 65000 < p_trial.stdout.size
                p_trial.stdout = "#{p_trial.stdout.mb_chars.limit(65000)}...(too long, truncated)"
              end
              save_log_file(trial.key, 'stderr', trial.stderr)

              p_trials << p_trial
            end
          end
          Persistence::Trial.import(p_trials)
        end

        ActiveRecord::Base.transaction do
          Persistence::WorkerLog.import(taskset.worker_logs.map do |worker_log|
            h = worker_log.to_h
            h['worker_key'] = h['worker']['key']
            h.delete('worker')
            h.delete('taskset')
            p_worker_log = Persistence::WorkerLog.new(h)
            p_worker_log.taskset_id = p_taskset
            if 65000 < p_worker_log.log.size
              p_worker_log.log = "#{p_worker_log.log.mb_chars.limit(65000)}...(too long, truncated)"
            end
            save_log_file(worker_log.key, 'worker_log', worker_log.log)
            p_worker_log
          end)
        end
      end

      def save_log_file(key, suffix, content)
        path = File.join(
          RRRSpec.configuration.execute_log_text_path,
          "#{key.gsub(/[\/:]/, '_')}_#{suffix}.log",
        )
        File.open(path, 'w') { |fp| fp.write(content) }
      end

      def create_api_cache(taskset, path)
        p_obj = Persistence::Taskset.where(key: taskset.key).full.first
        json = JSON.generate(p_obj.as_full_json.update('is_full' => true))

        FileUtils.mkdir_p(File.join(path, 'v1', 'tasksets'))
        json_path = File.join(path, 'v1', 'tasksets', taskset.key.gsub(':', '-'))
        IO.write(json_path, json)
        Zlib::GzipWriter.open(json_path + ".gz") { |gz| gz.write(json) }
      end

      ESTIMATION_FIELDS = [
        "`spec_file`",
        "avg(UNIX_TIMESTAMP(`trials`.`finished_at`)-UNIX_TIMESTAMP(`trials`.`started_at`)) as `avg`",
        # "avg(`trials`.`finished_at`-`trials`.`started_at`) as `avg`",
      ]

      def update_estimate_sec(taskset)
        p_obj = Persistence::Taskset.where(key: taskset.key).first
        taskset_class = p_obj.taskset_class
        query = Persistence::Task.joins(:trials).joins(:taskset).
          select(ESTIMATION_FIELDS).
          where('tasksets.taskset_class' => taskset_class).
          where('trials.status' => ["passed", "pending"]).
          group('spec_file')
        estimation = {}
        query.each do |row|
          estimation[row.spec_file] = row.avg.to_i
        end
        unless estimation.empty?
          TasksetEstimation.update_estimate_secs(taskset_class, estimation)
        end
      end
    end
  end
end
