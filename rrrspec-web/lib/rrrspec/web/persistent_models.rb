# Extensions to RRRSpec::Server::Persistence

module RRRSpec
  module Server
    module Persistence
      class Taskset
        def self.recent
          order('finished_at DESC')
        end

        def self.has_failed_slaves
          includes(:slaves).where(slaves: {status: 'failure_exit'})
        end

        def as_json_with_no_relation
          as_json(except: :id)
        end
      end
    end
  end
end
