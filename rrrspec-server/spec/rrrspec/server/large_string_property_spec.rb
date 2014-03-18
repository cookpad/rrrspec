require 'spec_helper'

module RRRSpec
  module Server
    class LargeStringDescriptorTestClass
      include LargeStringAttribute
      large_string :log

      def id; 1; end
    end

    describe LargeStringDescriptor do
      before do
        RRRSpec.application_type = :master
        RRRSpec.config = MasterConfig.new
        RRRSpec.config.execute_log_text_path = Dir.mktmpdir
      end

      after do
        FileUtils.remove_entry_secure(RRRSpec.config.execute_log_text_path)
      end

      subject { LargeStringDescriptorTestClass.new }

      it 'saves a content to a file' do
        subject.log = "log content"
        subject.log.flush

        filepath = File.join(
          RRRSpec.config.execute_log_text_path,
          'rrrspec',
          'server',
          'largestringdescriptortestclass',
          'log',
          '1',
        )
        expect(File.exists?(filepath)).to be_true
      end

      it 'deletes a key after flush' do
        subject.log = "log content"
        subject.log.flush
        expect(RRRSpec::Server.redis.keys('*')).to eq([])
      end
    end
  end
end
