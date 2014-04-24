module RRRSpec
  module Server
    module StatisticsUpdater
      ESTIMATION_FIELDS = [
        "`spec_file`",
        "avg(UNIX_TIMESTAMP(`trials`.`finished_at`)-UNIX_TIMESTAMP(`trials`.`started_at`)) as `avg`",
        # "avg(`trials`.`finished_at`-`trials`.`started_at`) as `avg`",
      ]

      module_function

      def work_loop
        loop { work }
      end

      def work
        taskset, recalculate = StatisticsUpdaterQueue.dequeue
        recalculate = true

        ActiveRecord::Base.connection_pool.with_connection do
          unless Persistence::Taskset.where(key: taskset.key).exists?
            RRRSpec.logger.warn("StatisticsUpdater: Ignoreing unpersisted taskset: #{taskset.key}")
          end

          if recalculate
            recalculate_estimate_sec taskset
          else
            update_estimate_sec taskset
          end
        end
      rescue
        RRRSpec.logger.error($!)
      end

      def update_estimate_sec(taskset)
      end

      def recalculate_estimate_sec(taskset)
        RRRSpec.logger.debug("Calculating estimate sec for taskset #{taskset.key}")

        start = Time.now 

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

        RRRSpec.logger.info("Recalculated estimate sec for taskset #{taskset.key} (total: #{Time.now - start} seconds)")
      end
    end
  end
end
