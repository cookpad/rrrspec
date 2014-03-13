module RRRSpec
  module Server
    def self.master_app(options={})
      RRRSpec.application_type = :master
      RRRSpec.config = MasterConfig.new
      load('config/configuration.rb') if File.exists?('config/configuration.rb')
      options.each { |key, value| RRRSpec.config[key] = value }

      ActiveRecord::Base.configuration ||=
        begin
          if File.exists?('config/database.yml')
            require "erb"
            YAML.load(ERB.new(IO.read(yaml)).result)
          end
        end
      ActiveRecord::Base.establish_connection

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
