module RRRSpec
  module Server
    module Persistence
      class Taskset < ActiveRecord::Base
        include ActiveModel::Serializers::JSON

        has_many :worker_logs
        has_many :slaves
        has_many :tasks

        scope :full, includes(
          :tasks => [{:trials => [:task, :slave]}, :taskset],
          :slaves => [:trials],
          :worker_logs => [:taskset]
        )

        def as_nodetail_json
          as_json(except: :id)
        end

        def as_short_json
          h = as_json(except: :id)
          h['slaves'] = slaves.map { |slave| slave.as_json(only: :key) }
          h['tasks'] = tasks.map { |task| task.as_json(only: :key) }
          h['worker_logs'] = worker_logs.map { |worker_log| worker_log.as_json(only: :key) }
          h
        end

        def as_full_json
          h = as_json(except: :id)
          h['slaves'] = slaves.map(&:as_full_json)
          h['tasks'] = tasks.map(&:as_full_json)
          h['worker_logs'] = worker_logs.map(&:as_full_json)
          h
        end
      end

      class Task < ActiveRecord::Base
        include ActiveModel::Serializers::JSON

        belongs_to :taskset
        has_many :trials

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

      class Trial < ActiveRecord::Base
        include ActiveModel::Serializers::JSON

        belongs_to :task
        belongs_to :slave

        def as_full_json
          as_json(except: [:id, :task_id, :slave_id],
                  include: { 'slave' => { only: :key }, 'task' => { only: :key } })
        end

        def as_short_json
          as_full_json
        end
      end

      class WorkerLog < ActiveRecord::Base
        include ActiveModel::Serializers::JSON

        belongs_to :taskset

        def as_full_json
          as_json(except: [:id, :taskset_id, :worker_key],
                  include: { 'taskset' => { only: :key } },
                  methods: :worker)
        end

        def as_short_json
          as_full_json
        end

        def worker
          { 'key' => worker_key }
        end
      end

      class Slave < ActiveRecord::Base
        include ActiveModel::Serializers::JSON

        has_many :trials

        def as_full_json
          as_json(except: [:id, :taskset_id],
                  include: { 'trials' => { only: :key } })
        end

        def as_short_json
          as_full_json
        end
      end
    end
  end
end
