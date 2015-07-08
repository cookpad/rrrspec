require 'spec_helper'

module RRRSpec
  RSpec.describe Web do
    before do
      RRRSpec.configuration = Web::WebConfiguration.new
      RRRSpec.configuration.redis = @redis
      RRRSpec.configuration.execute_log_text_path = Dir.mktmpdir
    end

    after do
      FileUtils.remove_entry_secure(RRRSpec.configuration.execute_log_text_path)
    end

    let(:taskset) do
      Taskset.create(
        'testuser', 'echo 1', 'echo 2', 'default', 'default', 3, 3, 5, 5
      )
    end

    let(:task) do
      Task.create(taskset, 10, 'spec/test_spec.rb')
    end

    let!(:worker) do
      Worker.create('default')
    end

    let!(:worker_log) do
      WorkerLog.create(worker, taskset)
    end

    let!(:slave) do
      Slave.create
    end

    let(:trial) do
      Trial.create(task, slave)
    end

    def taskset_id
      RRRSpec::Server::Persistence::Taskset.by_redis_model(taskset).first!.id
    end

    before do
      taskset.add_task(task)
      taskset.enqueue_task(task)

      ActiveTaskset.add(taskset)

      worker_log.set_rsync_finished_time
      worker_log.append_log('worker_log log body')
      worker_log.set_setup_finished_time

      taskset.add_slave(slave)
      slave.append_log('slave log body')

      trial.start
      trial.finish('pending', 'stdout body', 'stderr body', 10, 2, 0)

      task.update_status('pending')
      taskset.append_log('taskset log body')

      taskset.incr_succeeded_count
      taskset.finish_task(task)
      taskset.update_status('succeeded')
      taskset.set_finished_time

      ActiveTaskset.remove(taskset)

      slave.update_status('normal_exit')

      worker_log.set_finished_time
    end

    describe Web::API do
      include Rack::Test::Methods

      def app
        Web::API
      end

      describe "GET /v1/tasksets/actives" do
        before { ActiveTaskset.add(taskset) }

        it 'returns the active tasksets' do
          get "/v1/tasksets/actives"
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)).to eq(JSON.parse(ActiveTaskset.list.to_json))
        end
      end

      describe "GET /v1/tasksets/recents" do
        context 'there are 11 tasksets' do
          before do
            11.times { Server::Persistence::Taskset.create() }
          end

          it 'returns the recent 10 tasksets' do
            get "/v1/tasksets/recents"
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body).size).to eq(10)
          end
        end
      end

      describe "GET /v1/tasksets/:key" do
        context 'with the taskset persisted' do
          before do
            Server::Persister.persist(taskset)
          end

          it 'returns the taskset' do
            get "/v1/tasksets/#{taskset.key}"
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq(
              JSON.parse(Server::Persistence::Taskset.first.as_full_json.to_json).update("is_full" => true)
            )
          end
        end

        context 'with the taskset not persisted' do
          it 'returns 404' do
            get "/v1/tasksets/#{taskset.key}"
            expect(last_response.status).to eq(404)
          end
        end
      end

      describe "GET /v1/batch/tasks/:key" do
        it 'returns all tasks in the taskset' do
          get "/v1/batch/tasks/#{taskset.key}"
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)).to eq([JSON.parse(task.to_json)])
        end
      end
    end

    describe Web::APIv2 do
      include Rack::Test::Methods

      def app
        Web::APIv2
      end

      describe "GET /v2/tasksets/actives" do
        before { ActiveTaskset.add(taskset) }

        it 'returns the active tasksets' do
          get "/v2/tasksets/actives"
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)).to eq([
            { 'key' => taskset.key, 'status' => taskset.status, 'rsync_name' => taskset.rsync_name, 'created_at' => taskset.created_at.iso8601 },
          ])
        end
      end

      describe "GET /v2/tasksets/recents" do
        context 'there are 11 tasksets' do
          before do
            11.times { Server::Persistence::Taskset.create() }
          end

          it 'returns the recent 10 tasksets' do
            get "/v2/tasksets/recents"
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body).size).to eq(10)
          end
        end
      end

      shared_context 'the taskset is persisted' do
        before do
          Server::Persister.persist(taskset)
        end
      end

      describe 'GET /v2/tasksets/:taskset_key' do
        context "when the taskset is persisted" do
          include_context 'the taskset is persisted'

          it 'returns a taskset in JSON' do
            get "/v2/tasksets/#{taskset.key}"
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq({
              "created_at" => taskset.created_at.iso8601,
              "finished_at" => taskset.finished_at.iso8601,
              "id" => 1,
              "key" => taskset.key,
              "max_trials" => 3,
              "max_workers" => 3,
              "rsync_name" => "testuser",
              "setup_command" => "echo 1",
              "slave_command" => "echo 2",
              "status" => "succeeded",
              "tasks" => [
                {
                  "id" => 1,
                  "key" => task.key,
                  "status" => "pending",
                  "spec_path" => "spec/test_spec.rb",
                  "estimate_sec" => 10,
                  "trials" => [
                    {
                      "id" => 1,
                      "key" => trial.key,
                      "task_id" => 1,
                      "slave_id" => 1,
                      "started_at" => trial.started_at.iso8601,
                      "finished_at" => trial.finished_at.iso8601,
                      "status" => "pending",
                      "passed" => 10,
                      "pending" => 2,
                      "failed" => 0
                    },
                  ],
                },
              ],
              "taskset_class" => "default",
              "worker_type" => "default",
            })
          end
        end

        context "when the taskset is not persisted" do
          it "returns 404" do
            get "/v2/tasksets/#{taskset.key}"
            expect(last_response.status).to eq(404)
          end
        end
      end

      describe 'GET /v2/tasksets/:taskset_id/log' do
        context "when the taskset is persisted" do
          include_context 'the taskset is persisted'

          it 'returns a string in JSON' do
            get "/v2/tasksets/#{taskset_id}/log"
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq({
              'log' => 'taskset log body',
            })
          end
        end

        context "when the taskset is not persisted" do
          it "returns 404" do
            get "/v2/tasksets/0/log"
            expect(last_response.status).to eq(404)
          end
        end
      end

      describe 'GET /v2/tasks/:task_id/trials' do
        context "when the taskset is persisted" do
          include_context 'the taskset is persisted'

          it 'returns trials in JSON' do
            get "/v2/tasks/#{taskset_id}/trials"
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq([
              {
                "id" => 1,
                "key" => trial.key,
                "task_id" => 1,
                "slave_id" => 1,
                "started_at" => trial.started_at.iso8601,
                "finished_at" => trial.finished_at.iso8601,
                "status" => "pending",
                "passed" => 10,
                "pending" => 2,
                "failed" => 0,
              },
            ])
          end
        end

        context "when the taskset is not persisted" do
          it "returns 404" do
            get "/v2/tasksets/#{taskset.key}/trials"
            expect(last_response.status).to eq(404)
          end
        end
      end

      describe 'GET /v2/tasksets/:taskset_id/worker_logs' do
        context "when the taskset is persisted" do
          include_context 'the taskset is persisted'

          it 'returns worker logs in JSON' do
            get "/v2/tasksets/#{taskset_id}/worker_logs"
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq([
              {
                "id" => 1,
                "worker_name" => "rrrspec:worker:testhostname",
                "started_at" => worker_log.started_at.iso8601,
                "rsync_finished_at" => worker_log.rsync_finished_at.iso8601,
                "setup_finished_at" => worker_log.setup_finished_at.iso8601,
                "rspec_finished_at" => worker_log.finished_at.iso8601,
                "log" => "worker_log log body",
              },
            ])
          end
        end

        context "when the taskset is not persisted" do
          it "returns 404" do
            get "/v2/tasksets/0/worker_logs"
            expect(last_response.status).to eq(404)
          end
        end
      end

      describe 'GET /v2/tasksets/:taskset_id/slaves' do
        context "when the taskset is persisted" do
          include_context 'the taskset is persisted'

          it 'returns slaves in JSON' do
            get "/v2/tasksets/#{taskset_id}/slaves"
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)).to eq([
              {
                "id" => 1,
                "name" => slave.key,
                "status" => "normal_exit",
                "trials" => [
                  {
                    "id" => 1,
                    "key" => trial.key,
                  },
                ],
                "log" => "slave log body",
              },
            ])
          end
        end

        context "when the taskset is not persisted" do
          it "returns 404" do
            get "/v2/tasksets/0/slaves"
            expect(last_response.status).to eq(404)
          end
        end
      end

    end
  end
end
