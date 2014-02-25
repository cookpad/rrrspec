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
      end
    end
  end
end
