require 'spec_helper'

module RRRSpec
  module Server
    describe Persister do
      before do
        RRRSpec.configuration = Configuration.new
        RRRSpec.configuration.redis = @redis
      end

      before do
        @worker, @taskset, @task, @worker_log, @slave, @trial =
          RRRSpec.finished_fullset
      end

      describe '.persist' do
        let(:task_json) do
          {
            taskset: {key: @taskset.key},
            estimate_sec: @task.estimate_sec,
            key: @task.key,
            spec_file: @task.spec_file,
            status: @task.status,
            trials: [{key: @trial.key}],
          }
        end

        let(:slave_json) do
          {
            key: @slave.key,
            log: @slave.log,
            status: @slave.status,
            trials: [{key: @trial.key}],
          }
        end

        def eq_json(actual, expected)
          expect(
            JSON.parse(JSON.generate(actual))
          ).to eq(
            JSON.parse(JSON.generate(expected))
          )
        end

        def check_persistence
          Persister.persist(@taskset)
          p_taskset = Persistence::Taskset.first
          eq_json(p_taskset.as_short_json, @taskset)

          expect(p_taskset.tasks.size).to eq(1)
          p_task = p_taskset.tasks.first
          eq_json(p_task.as_short_json, task_json)

          trial = @task.trials[0]
          expect(p_task.trials.size).to eq(1)
          p_trial = p_task.trials.first
          eq_json(p_trial.as_short_json, @trial)

          expect(p_taskset.slaves.size).to eq(1)
          p_slave = p_taskset.slaves.first
          eq_json(p_slave.as_short_json, slave_json)

          expect(p_taskset.worker_logs.size).to eq(1)
          p_worker_log = p_taskset.worker_logs.first
          eq_json(p_worker_log.as_short_json, @worker_log)
        end

        it 'persists the whole taskset' do
          check_persistence
        end

        context "trial is finished after the taskset's finish" do
          before do
            @late_trial = Trial.create(@task, @slave)
            @late_trial.start
            Timecop.freeze(Time.now+1) do
              @late_trial.finish('error', '', '', nil, nil, nil)
            end
          end

          it "does not persist trials finished after taskset's finish" do
            check_persistence
          end
        end
      end

      describe '.create_api_cache' do
        before { Persister.persist(@taskset) }

        it 'writes cached json file' do
          Dir.mktmpdir do |dir|
            Persister.create_api_cache(@taskset, dir)
            json_path = File.join(dir, 'v1', 'tasksets', @taskset.key.gsub(':', '-'))
            expect(File).to exist(json_path)
            expect(File).to exist(json_path + ".gz")

            p_taskset = Persistence::Taskset.first
            expect(IO.read(json_path)).to eq(
              JSON.generate(p_taskset.as_full_json.update('is_full' => true))
            )
            expect(Zlib::GzipReader.open(json_path + ".gz").read).to eq(
              IO.read(json_path)
            )
          end
        end
      end

      describe '.update_estimate_sec' do
        before { Persister.persist(@taskset) }

        it 'udpates estimation of the time taken to finish the tasks' do
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
