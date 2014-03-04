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

        def log_exception
          yield
        rescue
          RRRSpec.logger.error($!)
          raise
        end

        def auto_rebirth
          Signal.trap('TERM') do
            Signal.trap('TERM', 'DEFAULT')
            Process.kill('TERM', 0)
          end
          loop do
            pid = Process.fork do
              log_exception { yield }
            end
            Process.waitpid(pid)
          end
        end

        def daemonize
          return unless options[:daemonize]
          pidfile = options[:pidfile]

          if pidfile
            pidfile = File.absolute_path(pidfile)
            if File.exists?(pidfile)
              pid = open(pidfile, 'r') { |f| f.read.strip }
              if pid
                begin
                  if Process.kill(0, pid.to_i) == 1
                    $stderr.puts "Daemon process already exists: #{pid}"
                    exit 1
                  end
                rescue Errno::ESRCH
                end
              end
            end
          end

          Process.daemon

          if pidfile
            open(pidfile, 'w') { |f| f.write(Process.pid.to_s) }

            parent_pid = Process.pid
            at_exit do
              if Process.pid == parent_pid
                File.delete(pidfile)
              end
            end
          end
        end
      end

      method_option :daemonize, type: :boolean
      method_option :pidfile, type: :string
      desc 'server', 'Run RRRSpec as a server'
      def server
        $0 = 'rrrspec server'
        setup(ServerConfiguration.new)
        daemonize
        auto_rebirth do
          ActiveRecord::Base.establish_connection(**RRRSpec.configuration.persistence_db)
          Thread.abort_on_exception = true
          Thread.fork { Dispatcher.work_loop }
          Thread.fork { Arbiter.work_loop }
          Thread.fork { Persister.work_loop }
          Kernel.sleep
        end
      end

      method_option :daemonize, type: :boolean
      method_option :pidfile, type: :string
      desc 'worker', 'Run RRRSpec as a worker'
      def worker
        $0 = 'rrrspec worker'
        setup(WorkerConfiguration.new)
        daemonize
        auto_rebirth do
          worker = Worker.create(RRRSpec.configuration.worker_type)
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
