require 'fiber'
require 'set'
require 'timeout'
require 'stringio'

require 'active_support/core_ext'
require 'eventmachine'
require 'extreme_timeout'
require 'faye/websocket'
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
        Fiber.new do
          WebSocketTransport.new(
            @handler,
            Faye::Websocket::Client.new(@master_url),
          )
        end.resume
      end
    end

    def self.slave_app
      RRRSpec.application_type = :slave
      SlaveApp.new(
        ENV['RRRSPEC_MASTER_URL'],
        [:taskset, ENV['RRRSPEC_TAKSET_ID'].to_i],
        ENV['RRRSPEC_WORKING_PATH'],
      )
    end
  end
end
