require 'fiber'
require 'fileutils'
require 'logger'
require 'open3'
require 'set'
require 'socket'
require 'securerandom'

require 'active_record'
require 'active_support'
require 'active_support/core_ext'
require 'active_support/inflector'
require 'active_support/time'
require 'bundler'
require 'faye/websocket'
require 'multi_json'
require 'rack'
require 'redis'

ActiveSupport::Inflector::Inflections.instance.singular('Slaves', 'Slave')
ActiveSupport::Inflector::Inflections.instance.singular('slaves', 'slave')
ActiveRecord::Base.include_root_in_json = false
ActiveRecord::Base.default_timezone = :utc

require 'rrrspec'
require 'rrrspec/server/applications'
require 'rrrspec/server/configuration'
require 'rrrspec/server/extension'
require 'rrrspec/server/json_constructor'
require 'rrrspec/server/json_rpc_transport'
require 'rrrspec/server/large_string_property'
require 'rrrspec/server/master_api_handler'
require 'rrrspec/server/models'
require 'rrrspec/server/rpc_logger'
require 'rrrspec/server/taskset_notificator'
require 'rrrspec/server/websocket_splitter'
require 'rrrspec/server/worker_api_handler'
require 'rrrspec/slave'

module RRRSpec
  module Server
    module_function

    def redis
      # After the process is daemonized, the redis instance is in invalid state.
      # We avoid using such instance by checking the PID.
      if not Thread.current[:pid] or Thread.current[:pid] != Process.pid
        Thread.current[:redis] = nil
        Thread.current[:pid] = Process.pid
      end

      # It is probable that if two other threads shares one redis connection
      # one thread blocks the other thread. We avoid this by using separate
      # connections.
      Thread.current[:redis] ||= Redis.new(config.redis)
    end

    def redis=(redis)
      Thread.current[:redis] = redis
      Thread.current[:pid] = Process.pid
    end

    def flushredis
      Thread.list.each do |thread|
        thread[:redis] = nil
        thread[:pid] = nil
      end
    end

    def generate_worker_name
      Socket.gethostname
    end
  end
end
