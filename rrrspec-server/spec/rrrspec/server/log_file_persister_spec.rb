require 'spec_helper'

module RRRSpec
  module Server
    class TestClass
      include LogFilePersister
      def self.after_save(&block); end
      save_as_file :log, suffix: 'log'

      attr_accessor :key
    end

    RSpec.describe LogFilePersister do
      before do
        RRRSpec.configuration = ServerConfiguration.new
        RRRSpec.configuration.execute_log_text_path = '/tmp/log_path'
      end

      describe '#log_log_path' do
        subject { TestClass.new }

        it 'subsitutes colons in the key' do
          subject.key = 'rrrspec:test'
          expect(subject.log_log_path).to eq('/tmp/log_path/rrrspec/test_log.log')
        end

        it 'subsitutes slashes in the key' do
          subject.key = 'rrrspec:test/path'
          expect(subject.log_log_path).to eq('/tmp/log_path/rrrspec/test_path_log.log')
        end
      end
    end
  end
end
