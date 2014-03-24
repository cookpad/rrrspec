module RRRSpec
  module Server
    module JSONConstructor
      module TasksetJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_json_for_index
          {
            'id' => id,
            'rsync_name' => rsync_name,
            'setup_command' => setup_command,
            'slave_command' => slave_command,
            'worker_type' => worker_type,
            'max_workers' => max_workers,
            'max_trials' => max_trials,
            'taskset_class' => taskset_class,
            'created_at' => created_at,
            'status' => status,
            'finished_at' => finished_at,
          }
        end

        def as_json_for_result_page
          as_json_for_index.merge(
            'tasks' => tasks.map(&:as_json_for_result_page),
          )
        end

        def as_summary_json
          statuses = tasks.pluck(:status)
          groups = statuses.group_by { |status| status }
          groups.default = []

          {
            'id' => id,
            'status' => status,
            'created_at' => created_at,
            'finished_at' => finished_at,
            'task_count' => statuses.count,
            'passed_count' => groups[Task::STATUS_PASSED].size,
            'pending_count' => groups[Task::STATUS_PENDING].size,
            'failed_count' => groups[Task::STATUS_FAILED].size,
          }
        end
      end

      module TaskJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_json_for_result_page
          {
            'id' => id,
            'taskset_id' => taskset_id,
            'status' => status,
            'spec_path' => spec_path,
            'hard_timeout_sec' => hard_timeout_sec,
            'soft_timeout_sec' => soft_timeout_sec,
            'spec_sha1' => spec_sha1,
            'trials' => trials.map(&:as_json_for_result_page)
          }
        end
      end

      module TrialJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_json_for_result_page
          {
            'id' => id,
            'task_id' => task_id,
            'slave_id' => slave_id,
            'started_at' => started_at,
            'finished_at' => finished_at,
            'status' => status,
            'passed' => passed,
            'pending' => pending,
            'failed' => failed,
          }
        end
      end

      module WorkerLogJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_json_for_result_page
          {
            'id' => id,
            'worker_name' => worker_name,
            'started_at' => started_at,
            'rsync_finished_at' => rsync_finished_at,
            'setup_finished_at' => setup_finished_at,
            'rspec_finished_at' => rspec_finished_at,
            'log' => log.to_s,
          }
        end
      end

      module SlaveJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_json_for_result_page
          {
            'id' => id,
            'name' => name,
            'status' => status,
            'trials' => trials.map(&:id),
          }
        end
      end
    end
  end
end
