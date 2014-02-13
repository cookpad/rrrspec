# Extensions to RRRSpec::Server::Persistence

module RRRSpec
  module Server
    module Persistence
      class Taskset
        scope :recent, order('finished_at DESC')
        scope :has_failed_slaves, includes(:slaves).where(slaves: {status: 'failure_exit'})

        def as_json_with_no_relation
          as_json(except: :id)
        end
      end
    end
  end
end
