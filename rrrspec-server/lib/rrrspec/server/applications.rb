module RRRSpec
  module Server
    def self.master_app(options={})
      RRRSpec.application_type = :master
      RRRSpec.config = MasterConfig.new
      load('config/configuration.rb') if File.exists?('config/configuration.rb')
      options.each { |key, value| RRRSpec.config[key] = value }

      if File.exists?('config/database.yml')
        require "yaml"
        require "erb"
        env = ENV["RACK_ENV"] ? ENV["RACK_ENV"] : "development"
        ActiveRecord::Base.establish_connection(
          YAML.load(ERB.new(IO.read('config/database.yml')).result)[env]
        )
      end
      WebSocketSplitter.new(MasterAPIHandler.new)
    end

    class WorkerApp
      def initialize
        @handler = WorkerAPIHandler.new
      end

      def run
        Fiber.new do
          WebSocketTransport.new(
            @handler,
            Faye::Websocket::Client.new(RRRSpec.config.master_url),
          )
        end.resume
      end
    end

    def self.worker_app(options={})
      RRRSpec.application_type = :worker
      RRRSpec.config = WorkerConfig.new
      load('config/configuration.rb') if File.exists?('config/configuration.rb')
      options.each { |key, value| RRRSpec.config[key] = value }

      WorkerApp.new
    end
  end
end
