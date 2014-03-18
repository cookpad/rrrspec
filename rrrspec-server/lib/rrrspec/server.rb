require 'fiber'
require 'fileutils'
require 'open3'
require 'securerandom'
require 'set'
require 'singleton'
require 'socket'

require 'active_model'
require 'active_record'
require 'active_support'
require 'active_support/core_ext'
require 'active_support/inflector'
require 'active_support/time'
require 'bundler'
require 'em-hiredis'
require 'eventmachine'
require 'faye/websocket'
require 'redis'
require 'redis/connection/hiredis'

ActiveSupport::Inflector::Inflections.instance.singular('Slaves', 'Slave')
ActiveSupport::Inflector::Inflections.instance.singular('slaves', 'slave')
ActiveRecord::Base.include_root_in_json = false
ActiveRecord::Base.default_timezone = :utc

require 'rrrspec'
require 'rrrspec/server/applications'
require 'rrrspec/server/configuration'
require 'rrrspec/server/daemonizer'
require 'rrrspec/server/extension'
require 'rrrspec/server/json_constructor'
require 'rrrspec/server/large_string_property'
require 'rrrspec/server/master_api_handler'
require 'rrrspec/server/models'
require 'rrrspec/server/rpc_logger'
require 'rrrspec/server/taskset_notificator'
require 'rrrspec/server/websocket_splitter'
require 'rrrspec/server/worker_api_handler'

module RRRSpec
  module Server
    module_function

    # TODO: These are not fork aware. We should consider pre-fork environments.

    def redis
      Thread.current[:redis] ||= Redis.new(url: RRRSpec.config.redis)
    end

    def redis=(redis)
      Thread.current[:redis] = redis
    end
  end
end
