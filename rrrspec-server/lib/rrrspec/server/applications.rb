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

    def self.master_after_fork_initialize
      Thread.new { EM.run } unless EM.reactor_running?
      Thread.pass until EM.reactor_running?
      em_hiredis = EM::Hiredis.connect(RRRSpec.config.redis)

      TasksetNotificator.instance.register_pubsub(em_hiredis)
      Taskset.after_update(&TasksetNotificator.instance.method(:taskset_updated))
      Task.after_update(&TasksetNotificator.instance.method(:task_updated))
      Trial.after_create(&TasksetNotificator.instance.method(:trial_created))
      Trial.after_update(&TasksetNotificator.instance.method(:trial_updated))
      WorkerLog.after_create(&TasksetNotificator.instance.method(:worker_log_created))
      WorkerLog.after_update(&TasksetNotificator.instance.method(:worker_log_updated))
      Slave.after_create(&TasksetNotificator.instance.method(:slave_created))
      Slave.after_update(&TasksetNotificator.instance.method(:slave_updated))

      GlobalNotificator.instance.register_pubsub(em_hiredis)
      Taskset.after_create(&GlobalNotificator.instance.method(:taskset_created))
      Taskset.after_update(&GlobalNotificator.instance.method(:taskset_updated))

      Worker.instance.register_pubsub(em_hiredis)
      Taskset.after_update(&Worker.instance.method(:taskset_updated))
    end

    class WorkerApp
      def initialize
        @handler = WorkerAPIHandler.new
      end

      def run
        WebSocketTransport.new(@handler, RRRSpec.config.master_url, auto_reconnect: true)
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
