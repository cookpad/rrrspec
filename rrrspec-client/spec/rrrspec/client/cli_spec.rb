require 'spec_helper'
require 'rrrspec/client/cli'

module RRRSpec
  module Client
    describe CLI do
      before do
        RRRSpec.configuration = Configuration.new
        RRRSpec.configuration.redis = @redis
        described_class.class_eval do
          no_commands do
            def setup(arg)
            end
          end
        end
      end

      describe '#cancelall' do
        let!(:taskset1) do
          Taskset.create('rsync_name', '', '', 'default', 'nothing', 3, 3, 3, 3)
        end
        let!(:taskset2) do
          Taskset.create('rsync_name', '', '', 'default', 'nothing', 3, 3, 3, 3)
        end
        let!(:taskset3) do
          Taskset.create('another_rsync_name', '', '', 'default', 'nothing', 3, 3, 3, 3)
        end

        before do
          ActiveTaskset.add(taskset1)
          ActiveTaskset.add(taskset2)
          ActiveTaskset.add(taskset3)
        end

        it 'cancels all tasksets' do
          subject.cancelall('rsync_name')
          Timeout.timeout(3) do
            expect(ArbiterQueue.dequeue).to eq(['cancel', taskset1])
            expect(ArbiterQueue.dequeue).to eq(['cancel', taskset2])
          end
        end
      end
    end
  end
end
