module RRRSpec
  module Server
    RESPAWN_INTERVAL_LIMIT_SEC = 30

    def self.daemonizer(process_name, &block)
      $0 = process_name
      return block.call unless should_daemonize?

      pidfile = File.absolute_path(RRRSpec.configuration.pidfile || File.join("/var/run", "#{process_name}.pid"))
      check_pidfile(pidfile)

      if stdout_path = RRRSpec.configuration.stdout_path
        $stdout.reopen(stdout_path, 'a')
      end
      if stderr_path = RRRSpec.configuration.stderr_path
        $stderr.reopen(stderr_path, 'a')
      end
      Process.daemon(false, true)
      File.write(pidfile, Process.pid.to_s)
      setup_signal_handlers
      setup_atexit_handlers(pidfile)
      monitor_fork do
        Process::Sys.setuid(RRRSpec.configuration.user) if RRRSpec.configuration.user
        block.call
      end
    end

    def self.should_daemonize?
      RRRSpec.configuration.daemonize == nil || RRRSpec.configuration.daemonize
    end

    def self.should_monitor?
      RRRSpec.configuration.monitor == nil || RRRSpec.configuration.monitor
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

    def self.setup_atexit_handlers(pidfile)
      # Delete pid at exit
      current_pid = Process.pid
      at_exit do
        # Since at_exit handlers are inherited by child processes, it is the
        # case that the handlers are invoked in the child processes. This guard
        # is needed to avoid this.
        File.delete(pidfile) if Process.pid == current_pid
      end
    end

    def self.monitor_fork(&block)
      loop do
        started_at = Time.now
        pid = Process.fork(&block)
        Process.waitpid(pid)
        break unless should_monitor?
        if Time.now - started_at < RESPAWN_INTERVAL_LIMIT_SEC
          sleep RESPAWN_INTERVAL_LIMIT_SEC
        end
      end
    end
  end
end
