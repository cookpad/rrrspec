module RRRSpec
  module Server
    module JSONConstructor
      module TasksetJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_nodetail_json
          as_json(methods: :log)
        end

        def as_short_json
          h = as_json(methods: :log)
          h['slaves'] = slaves.map { |slave| slave.as_json(only: :id) }
          h['tasks'] = tasks.map { |task| task.as_json(only: :id) }
          h['worker_logs'] = worker_logs.map { |worker_log| worker_log.as_json(only: :id) }
          h
        end

        def as_full_json
          h = as_json(methods: :log)
          h['slaves'] = slaves.map(&:as_full_json)
          h['tasks'] = tasks.map(&:as_full_json)
          h['worker_logs'] = worker_logs.map(&:as_full_json)
          h
        end

        def as_summary_json
          h = Hash.new
          h['status'] = status
          h['created_at'] = created_at
          h['finished_at'] = finished_at

          statuses = tasks.pluck(:status)
          groups = statuses.group_by { |status| status }
          groups.default = []
          h['task_count'] = statuses.count
          h['passed_count'] = groups[Task::STATUS_PASSED].size
          h['pending_count'] = groups[Task::STATUS_PENDING].size
          h['failed_count'] = groups[Task::STATUS_FAILED].size
          h
        end
      end

      module TaskJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_short_json
          h = as_json(except: [:taskset_id, :trials],
                      include: { 'taskset' => { only: :id} })
          h['trials'] = trials.map { |trial| trial.as_json(only: :id) }
          h
        end

        def as_full_json
          h = as_json(except: [:taskset_id, :trials],
                      include: { 'taskset' => { only: :id } })
          h['trials'] = trials.map(&:as_full_json)
          h
        end
      end

      module TrialJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_short_json
          as_full_json
        end

        def as_full_json
          as_json(except: [:task_id, :slave_id],
                  include: { 'slave' => { only: :id }, 'task' => { only: :id } },
                  methods: [:stdout, :stderr])
        end
      end

      module WorkerLogJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_short_json
          as_full_json
        end

        def as_full_json
          as_json(except: [:taskset_id, :worker_name],
                  include: { 'taskset' => { only: :id } },
                  methods: [:worker, :log])
        end

        def worker
          { 'worker_name' => worker_name }
        end
      end

      module SlaveJSONConstructor
        extend ActiveSupport::Concern
        include ActiveModel::Serializers::JSON

        def as_short_json
          as_full_json
        end

        def as_full_json
          as_json(except: [:taskset_id],
                  include: { 'trials' => { only: :id } },
                  methods: [:log])
        end
      end
    end
  end
end
