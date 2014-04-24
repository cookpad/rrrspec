require 'rrrspec/server'
require 'thor'

module RRRSpec
  module Server
    class CLI < Thor
      package_name 'RRRSpec'
      default_command 'help'
      class_option :config, aliases: '-c',  type: :string, default: ''

      no_commands do
        def setup(conf)
          RRRSpec.setup(conf, options[:config].split(':'))
        end
      end

      method_option :daemonize, type: :boolean
      method_option :pidfile, type: :string
      method_option :user, type: :string
      desc 'server', 'Run RRRSpec as a server'
      def server
        setup(ServerConfiguration.new)
        RRRSpec.configuration.daemonize = options[:daemonize] unless options[:daemonize] == nil
        RRRSpec.configuration.pidfile = options[:pidfile] unless options[:pidfile] == nil
        RRRSpec.configuration.user = options[:user] unless options[:user] == nil

        RRRSpec::Server.daemonizer('rrrspec-server server') do
          ActiveRecord::Base.establish_connection(**RRRSpec.configuration.persistence_db)
          Thread.abort_on_exception = true
          Thread.fork { Dispatcher.work_loop }
          Thread.fork { Arbiter.work_loop }
          Thread.fork { Persister.work_loop }
          Thread.fork { StatisticsUpdater.work_loop }
          Kernel.sleep
        end
      end

      method_option :'worker-type', type: :string
      method_option :daemonize, type: :boolean
      method_option :pidfile, type: :string
      method_option :user, type: :string
      desc 'worker', 'Run RRRSpec as a worker'
      def worker
        setup(WorkerConfiguration.new)
        RRRSpec.configuration.daemonize = options[:daemonize] unless options[:daemonize] == nil
        RRRSpec.configuration.pidfile = options[:pidfile] unless options[:pidfile] == nil
        RRRSpec.configuration.user = options[:user] unless options[:user] == nil

        RRRSpec::Server.daemonizer('rrrspec-server worker') do
          worker = Worker.create(options[:'worker-type'] || RRRSpec.configuration.worker_type)
          worker_runner = WorkerRunner.new(worker)
          Thread.abort_on_exception = true
          Thread.fork { RRRSpec.pacemaker(worker, 60, 5) }
          Thread.fork { worker_runner.work_loop }
          Kernel.sleep
        end
      end
    end
  end
end
