require 'spec_helper'

module RRRSpec
  describe Web::API do
    include Rack::Test::Methods

    def app
      Web::API
    end

    before do
      RRRSpec.configuration = Configuration.new
      RRRSpec.configuration.redis = @redis
    end

    let(:taskset) do
      Taskset.create(
        'testuser', 'echo 1', 'echo 2', 'default', 'default', 3, 3, 5, 5
      )
    end

    let(:task) do
      Task.create(taskset, 10, 'spec/test_spec.rb')
    end

    let(:worker) do
      Worker.create('default')
    end

    let(:worker_log) do
      WorkerLog.create(worker, taskset)
    end

    let(:slave) do
      Slave.create
    end

    before do
      worker # Create worker
      taskset.add_task(task)
      taskset.enqueue_task(task)
      ActiveTaskset.add(taskset)
      worker_log # Create worker_log
      worker_log.set_rsync_finished_time
      worker_log.append_log('worker_log log body')
      worker_log.set_setup_finished_time
      slave # Create slave
      taskset.add_slave(slave)
      slave.append_log('slave log body')
      trial = Trial.create(task, slave)
      trial.start
      trial.finish('pending', 'stdout body', 'stderr body', 10, 2, 0)
      task.update_status('pending')
      taskset.incr_succeeded_count
      taskset.finish_task(task)
      taskset.update_status('succeeded')
      taskset.set_finished_time
      ActiveTaskset.remove(taskset)
      slave.update_status('normal_exit')
      worker_log.set_finished_time
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
            JSON.parse(JSON.generate(Server::Persistence::Taskset.first.as_full_json)).update("is_full" => true)
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
end
