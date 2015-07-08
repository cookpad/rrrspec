require 'spec_helper'

module RRRSpec
  module Server
    RSpec.describe StatisticsUpdater do
      before do
        RRRSpec.configuration = ServerConfiguration.new
        RRRSpec.configuration.redis = @redis

        @worker, @taskset, @task, @worker_log, @slave, @trial =
          RRRSpec.finished_fullset
      end

      describe '.update_estimate_sec' do
        before { Persister.persist(@taskset) }

        xit 'updates estimation of the time taken to finish the tasks' do
          pending "sqlite3 doesn't have UNIT_TIMESTAMP function"
          Persister.update_estimate_sec(@taskset)
          expect(RRRSpec::TasksetEstimation.estimate_secs(@taskset.taskset_class)).to eq(
            {"spec/test_spec.rb" => 0}
          )
        end
      end
    end
  end
end

