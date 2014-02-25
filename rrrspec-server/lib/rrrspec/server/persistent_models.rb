module RRRSpec
  module Server
    module Persistence
      class Taskset < ActiveRecord::Base
        include JSONConstructor::TasksetJSONConstructor
        include LogFilePersister
        has_many :worker_logs
        has_many :slaves
        has_many :tasks
        save_as_file :log, suffix: 'log'

        def self.full
          includes(
            :tasks => [{:trials => [:task, :slave]}, :taskset],
            :slaves => [:trials],
            :worker_logs => [:taskset]
          )
        end
      end

      class Task < ActiveRecord::Base
        include JSONConstructor::TaskJSONConstructor
        belongs_to :taskset
        has_many :trials
      end

      class Trial < ActiveRecord::Base
        include JSONConstructor::TrialJSONConstructor
        include LogFilePersister
        belongs_to :task
        belongs_to :slave
        save_as_file :stdout, suffix: 'stdout'
        save_as_file :stderr, suffix: 'stderr'
      end

      class WorkerLog < ActiveRecord::Base
        include JSONConstructor::WorkerLogJSONConstructor
        include LogFilePersister
        belongs_to :taskset
        save_as_file :log, suffix: 'worker_log'
      end

      class Slave < ActiveRecord::Base
        include JSONConstructor::SlaveJSONConstructor
        include LogFilePersister
        has_many :trials
        save_as_file :log, suffix: 'slave_log'
      end
    end
  end
end
