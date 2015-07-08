require 'facter'

module RRRSpec
  module Server
    class ServerConfiguration < Configuration
      attr_accessor :persistence_db
      attr_accessor :execute_log_text_path
      attr_accessor :daemonize, :pidfile, :user
      attr_accessor :stdout_path, :stderr_path
      attr_accessor :monitor

      def initialize
        super()
        @type = :server
      end

      def check_validity
        validity = super

        unless execute_log_text_path
          $stderr.puts('The path to save the log text should be set')
          validity = false
        end

        unless persistence_db
          $stderr.puts('The database options are not set')
          validity = false
        end

        validity
      end
    end

    class WorkerConfiguration < Configuration
      attr_accessor :rsync_remote_path, :rsync_options
      attr_accessor :working_dir, :worker_type, :slave_processes
      attr_accessor :daemonize, :pidfile, :user
      attr_accessor :stdout_path, :stderr_path
      attr_accessor :monitor

      def initialize
        super()
        @slave_processes = Facter.value(:processorcount).to_i
        @worker_type = 'default'
        @type = :worker
      end

      def check_validity
        validity = super

        unless rsync_remote_path and rsync_options
          $stderr.puts('The rsync options are not set')
          validity = false
        end

        unless working_dir and worker_type
          $stderr.puts('The worker options are not set')
          validity = false
        end

        validity
      end
    end
  end
end
