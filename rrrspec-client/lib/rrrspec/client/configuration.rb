module RRRSpec
  module Client
    class ClientConfiguration < Configuration
      attr_accessor :packaging_dir
      attr_accessor :rsync_remote_path, :rsync_options
      attr_writer :spec_files
      attr_accessor :setup_command, :slave_command
      attr_accessor :taskset_class, :worker_type
      attr_accessor :max_workers, :max_trials
      attr_accessor :rrrspec_web_base
      attr_accessor :unknown_spec_timeout_sec, :least_timeout_sec

      def spec_files
        case @spec_files
        when Proc then @spec_files.call
        when String then [@spec_files]
        else @spec_files
        end
      end

      def initialize
        super()
        @type = :client
        @unknown_spec_timeout_sec = 5 * 60
        @least_timeout_sec = 30
      end

      def check_validity
        validity = super

        unless Dir.exists?(packaging_dir)
          $stderr.puts("The packaging_dir does not exists: '#{packaging_dir}'")
          validity = false
        end

        unless spec_files.is_a?(Array)
          $stderr.puts("The spec_files should be an Array: '#{spec_files}'")
          validity = false
        else
          spec_files.each do |filepath|
            unless File.exists?(File.join(packaging_dir, filepath))
              $stderr.puts("One of the spec_files does not exists '#{filepath}'")
              validity = false
            end
          end
        end

        unless max_workers.is_a?(Integer)
          $stderr.puts("The max_workers should be an Integer: '#{max_workers}'")
          validity = false
        else
          unless max_workers >= 1
            $stderr.puts("The max_workers should not be less than 1: #{max_workers}")
            validity = false
          end
        end

        unless max_trials.is_a?(Integer)
          $stderr.puts("The max_trials should be an Integer: '#{max_trials}'")
          validity = false
        end

        unless taskset_class.is_a?(String)
          $stderr.puts("The taskset_class should be a String: '#{taskset_class}'")
          validity = false
        end

        unless unknown_spec_timeout_sec.is_a?(Integer)
          $stderr.puts("The unknown_spec_timeout_sec should be an Integer: '#{unknown_spec_timeout_sec}'")
          validity = false
        end

        unless least_timeout_sec.is_a?(Integer)
          $stderr.puts("The least_timeout_sec should be an Integer: '#{least_timeout_sec}'")
          validity = false
        end

        validity
      end
    end
  end
end
