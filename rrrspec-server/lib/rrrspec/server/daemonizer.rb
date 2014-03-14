module RRRSpec
  module Sever
    RESPAWN_INTERVAL_LIMIT_SEC = 30

    def self.daemonizer(process_name, &block)
      return block.call unless should_daemonize?

      pidfile = RRRSpec.config.pidfile || File.join("/var/run", "#{process_name}.pid")
      check_pidfile(pidfile)

      Process.daemon
      File.write(pidfile, Process.pid.to_s)
      File.umask(0)
      setup_signal_handlers
      setup_atexit_handlers

      if should_monitor?
        monitor_fork(&block)
      else
        block.call
      end
    end

    def self.should_daemonize?
      RRRSpec.config.daemonize == nil || RRRSpec.config.daemonize
    end

    def self.should_monitor?
      RRRSpec.config.monitor == nil || RRRSpec.config.monitor
    end

    def self.check_pidfile(pidfile)
      if File.exist?(pidfile)
        if File.readable?(pidfile)
          pid = File.read(pidfile).to_i
          begin
            Process.kill(0, pid)
            raise "Pid(#{pid}) is running"
          rescue Errno::EPERM
            raise "Pid(#{pid}) is running"
          rescue Errno::ESRCH
          end
        else
          raise "Cannot access #{pidfile}"
        end

        unless File.writable?(pidfile)
          raise "Cannot access #{pidfile}"
        end
      else
        unless File.writable?(File.dirname(pidfile))
          raise "Cannot access #{pidfile}"
        end
      end
    end

    def self.setup_signal_handlers
      # Propagate the TERM signal to the children
      Signal.trap('TERM') do
        Signal.trap('TERM', 'DEFAULT')
        Process.kill('TERM', 0)
      end
    end

    def self.setup_atexit_handlers
      # Delete pid at exit
      current_pid = Process.pid
      at_exit do
        # Since at_exit handlers are inherited by child processes, it is the
        # case that the handlers are invoked in the child processes. This guard
        # is needed to avoid this.
        File.delete(pidfile) if Process.pid == current_pid
      end
    end

    def self.monitor_fork
      loop do
        started_at = Time.now
        pid = Process.fork do
          block.call
        end
        Process.waitpid(pid)
        if Time.now - started_at < RESPAWN_INTERVAL_LIMIT_SEC
          sleep RESPAWN_INTERVAL_LIMIT_SEC
        end
      end
    end
  end
end
