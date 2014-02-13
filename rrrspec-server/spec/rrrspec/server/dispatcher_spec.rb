require 'spec_helper'

module RRRSpec
  module Server
    describe Dispatcher do
      before do
        RRRSpec.configuration = Configuration.new
        RRRSpec.configuration.redis = @redis
      end

      describe '#work' do
        context 'when the worker no longer exists' do
          let(:worker) { Worker.create('default', 'hostname1') }
          before { worker }

          it 'evicts the worker' do
            Dispatcher.work
            expect(Worker.list).not_to include(worker)
          end
        end

        context 'a worker exists' do
          let(:taskset) do
            Taskset.create(
              'testuser', 'echo 1', 'echo 2', 'default', 'default', 3, 3, 5, 5
            )
          end

          let(:worker1) { Worker.create('default', 'hostname1') }
          let(:worker2) { Worker.create('default', 'hostname2') }
          let(:worker3) { Worker.create('default', 'hostname3') }
          let(:worker4) { Worker.create('default', 'hostname4') }

          before do
            ActiveTaskset.add(taskset)
            worker1.update_current_taskset(taskset)
            worker1.heartbeat(30)
            worker2.heartbeat(30)
            worker3.heartbeat(30)
            worker4.heartbeat(30)
          end

          it 'assignes worker upto the max_workers' do
            Dispatcher.work
            expect(worker1.queue_empty?).to be_true
            workers = [worker1, worker2, worker3, worker4]
            expect(workers.count { |worker| worker.queue_empty? }).to eq(2)
          end
        end
      end
    end
  end
end
