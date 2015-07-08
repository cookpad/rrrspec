require 'spec_helper'

module RRRSpec
  module Server
    module Persistence
      RSpec.describe Taskset do
        before do
          RRRSpec.configuration = ServerConfiguration.new
          RRRSpec.configuration.redis = @redis
          RRRSpec.configuration.execute_log_text_path = Dir.mktmpdir
        end

        before do
          @worker, @taskset, @task, @worker_log, @slave, @trial =
            RRRSpec.finished_fullset
          Persister.persist(@taskset)
        end

        describe '#as_nodetail_json' do
          it 'produces a json object' do
            h = @taskset.to_h
            h.delete('slaves')
            h.delete('tasks')
            h.delete('worker_logs')

            expect(
              JSON.parse(JSON.generate(Taskset.first.as_nodetail_json()))
            ).to eq(
              JSON.parse(JSON.generate(h))
            )
          end
        end

        describe '#as_full_json' do
          it 'produces a json object' do
            h = @taskset.to_h
            h['slaves'] = [@slave.to_h]

            task_h = @task.to_h
            task_h['trials'] = [@trial.to_h]
            h['tasks'] = [task_h]

            h['worker_logs'] = [@worker_log.to_h]

            expect(
              JSON.parse(JSON.generate(Taskset.first.as_full_json()))
            ).to eq(
              JSON.parse(JSON.generate(h))
            )
          end
        end
      end
    end
  end
end
