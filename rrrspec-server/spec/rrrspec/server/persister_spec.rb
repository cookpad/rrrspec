require 'spec_helper'

module RRRSpec
  module Server
    RSpec.describe Persister do
      before do
        RRRSpec.configuration = ServerConfiguration.new
        RRRSpec.configuration.redis = @redis
        RRRSpec.configuration.execute_log_text_path = Dir.mktmpdir
      end

      before do
        @worker, @taskset, @task, @worker_log, @slave, @trial =
          RRRSpec.finished_fullset
      end

      after do
        FileUtils.remove_entry_secure(RRRSpec.configuration.execute_log_text_path)
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

        def log_path_of(filename)
          File.join(RRRSpec.configuration.execute_log_text_path, filename)
        end

        let(:taskset_log_name)  { @taskset.key.gsub(/\//, '_').gsub(/:/, '/') + "_log.log" }
        let(:worker_log_name)   { @worker_log.key.gsub(/\//, '_').gsub(/:/, '/') + "_worker_log.log" }
        let(:slave_log_name)    { @slave.key.gsub(/\//, '_').gsub(/:/, '/') + "_slave_log.log" }
        let(:trial_stdout_name) { @trial.key.gsub(/\//, '_').gsub(/:/, '/') + "_stdout.log" }
        let(:trial_stderr_name) { @trial.key.gsub(/\//, '_').gsub(/:/, '/') + "_stderr.log" }

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

        context 'when logs are too long' do
          before do
            RRRSpec.redis.hset(@trial.key, 'stdout', 'out' * 30000)
          end

          it 'saves full logs to the files' do
            Persister.persist(@taskset)
            expect(File.read(log_path_of(trial_stdout_name))).to eq(@trial.stdout)
          end
        end


        it 'creates log text files' do
          Persister.persist(@taskset)

          expect(File.read(log_path_of(taskset_log_name))).to eq(@taskset.log)
          expect(File.read(log_path_of(worker_log_name))).to eq(@worker_log.log)
          expect(File.read(log_path_of(slave_log_name))).to eq(@slave.log)
          expect(File.read(log_path_of(trial_stdout_name))).to eq(@trial.stdout)
          expect(File.read(log_path_of(trial_stderr_name))).to eq(@trial.stderr)
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
    end
  end
end
