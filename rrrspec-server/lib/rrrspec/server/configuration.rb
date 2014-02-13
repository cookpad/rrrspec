require 'facter'

module RRRSpec
  module Server
    class ServerConfiguration < Configuration
      attr_accessor :rsync_server, :rsync_dir, :rsync_options
      attr_accessor :persistence_db
      attr_accessor :json_cache_path

      def initialize
        super()
        @type = :server
      end

      def check_validity
        validity = super

        unless rsync_server and rsync_options and rsync_dir
          $stderr.puts('The rsync options are not set')
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
      attr_accessor :working_dir, :worker_type, :slave_processes

      def initialize
        super()
        @slave_processes = Facter.processorcount.to_i
        @worker_type = 'default'
        @type = :worker
      end

      def check_validity
        validity = super

        unless working_dir and worker_type
          $stderr.puts('The worker options are not set')
          validity = false
        end

        validity
      end
    end
  end
end
