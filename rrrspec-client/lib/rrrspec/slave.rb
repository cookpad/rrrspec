require 'fiber'
require 'set'
require 'timeout'
require 'stringio'

require 'active_support/core_ext'
require 'eventmachine'
require 'extreme_timeout'
require 'rspec'
require 'rspec/core/formatters/base_text_formatter'

require 'rrrspec'
require 'rrrspec/slave/slave_api_handler'
require 'rrrspec/slave/rspec_runner'

module RRRSpec
  module Slave
    class SlaveApp
      def initialize(master_url, taskset_ref, working_path)
        @master_url = master_url
        @handler = SlaveAPIHandler.new(taskset_ref, working_path)
      end

      def run
        WebSocketTransport.new(@handler, @master_url, auto_reconnect: true)
      end
    end

    def self.slave_app
      RRRSpec.application_type = :slave
      SlaveApp.new(
        ENV['RRRSPEC_MASTER_URL'],
        ['taskset', ENV['RRRSPEC_TASKSET_ID'].to_i],
        ENV['RRRSPEC_WORKING_PATH'],
      )
    end
  end
end
