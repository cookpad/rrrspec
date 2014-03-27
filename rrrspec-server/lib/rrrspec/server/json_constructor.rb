module RRRSpec
  module Server
    module JSONConstructor
      module TasksetJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_nodetail_json
          as_json(except: :id, methods: :log)
        end

        def as_short_json
          h = as_json(except: :id, methods: :log)
          h['slaves'] = slaves.map { |slave| slave.as_json(only: :key) }
          h['tasks'] = tasks.map { |task| task.as_json(only: :key) }
          h['worker_logs'] = worker_logs.map { |worker_log| worker_log.as_json(only: :key) }
          h
        end

        def as_full_json
          h = as_json(except: :id, methods: :log)
          h['slaves'] = slaves.map(&:as_full_json)
          h['tasks'] = tasks.map(&:as_full_json)
          h['worker_logs'] = worker_logs.map(&:as_full_json)
          h
        end

        def as_json_for_index
          {
            'id' => id,
            'key' => key,
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
            'key' => key,
            'status' => status,
            'created_at' => created_at,
            'finished_at' => finished_at,
            'task_count' => statuses.count,
            'passed_count' => groups['passed'].size,
            'pending_count' => groups['pending'].size,
            'failed_count' => groups['failed'].size,
          }
        end
      end

      module TaskJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_short_json
          h = as_json(except: [:id, :taskset_id, :trials],
                      include: { 'taskset' => { only: :key } })
          h['trials'] = trials.map { |trial| trial.as_json(only: :key) }
          h
        end

        def as_full_json
          h = as_json(except: [:id, :taskset_id, :trials],
                      include: { 'taskset' => { only: :key } })
          h['trials'] = trials.map(&:as_full_json)
          h
        end

        def as_json_for_result_page
          {
            'id' => id,
            'key' => key,
            'status' => status,
            'spec_path' => spec_file,
            'estimate_sec' => estimate_sec,
            'trials' => trials.map(&:as_json_for_result_page),
          }
        end
      end

      module TrialJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_short_json
          as_full_json
        end

        def as_full_json
          as_json(except: [:id, :task_id, :slave_id],
                  include: { 'slave' => { only: :key }, 'task' => { only: :key } },
                  methods: [:stdout, :stderr])
        end

        def as_json_for_result_page
          {
            'id' => id,
            'key' => key,
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

        def as_short_json
          as_full_json
        end

        def as_full_json
          as_json(except: [:id, :taskset_id, :worker_key],
                  include: { 'taskset' => { only: :key } },
                  methods: [:worker, :log])
        end

        def worker
          { 'key' => worker_key }
        end

        def as_json_for_result_page
          {
            'id' => id,
            'worker_name' => worker_key,
            'started_at' => started_at,
            'rsync_finished_at' => rsync_finished_at,
            'setup_finished_at' => setup_finished_at,
            'rspec_finished_at' => finished_at,
            'log' => log.to_s,
          }
        end
      end

      module SlaveJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_short_json
          as_full_json
        end

        def as_full_json
          as_json(except: [:id, :taskset_id],
                  include: { 'trials' => { only: :key } },
                  methods: [:log])
        end

        def as_json_for_result_page
          {
            'id' => id,
            'name' => key,
            'status' => status,
            'trials' => trials.map { |trial| { id: trial.id, key: trial.key } },
            'log' => log.to_s,
          }
        end
      end
    end
  end
end
