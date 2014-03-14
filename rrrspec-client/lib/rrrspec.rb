require 'logger'

require 'active_support'
require 'active_support/core_ext'
require 'faye/websocket'
require 'multi_json'
require 'rack'

require 'rrrspec/json_rpc_transport'

module RRRSpec
  mattr_accessor :application_type
  mattr_accessor :config

  module_function

  def configure(type=nil)
    if type == nil || type == application_type
      yield config
    end
  end

  def logger
    @logger ||= Logger.new(STDERR)
  end

  def logger=(logger)
    @logger = logger
  end

  def generate_worker_name
    Socket.gethostname
  end

  def generate_slave_name(uuid=nil)
    uuid ||= ENV['RRRSPEC_SLAVE_UUID']
    "#{generate_worker_name}:#{uuid}"
  end
end
