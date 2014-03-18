module RRRSpec
  module Client
    class TasksetBuilder
      HARD_TIMEOUT_MULTIPLIER = 5
      SOFT_TIMEOUT_MULTIPLIER = 3

      attr_accessor :rsync_name
      attr_accessor :setup_command, :slave_command
      attr_accessor :worker_type, :taskset_class, :max_workers, :max_trials
      attr_accessor :spec_files

      def initialize(transport, unknown_spec_timeout_sec, least_timeout_sec)
        @transport = transport
        @unknown_spec_timeout_sec = unknown_spec_timeout_sec
        @least_timeout_sec = least_timeout_sec
      end

      def start
        @transport.sync_call(
          :create_taskset,
          rsync_name,
          setup_command,
          slave_command,
          worker_type,
          taskset_class,
          max_workers,
          max_trials,
          build_task_argument,
        )
      end

      private

      def build_task_argument
        spec_files.map do |spec_path|
          filepath = File.join(RRRSpec.config.packaging_dir, spec_path)
          raise "Spec file not found: #{spec_path}" unless File.exists?(filepath)
          spec_sha1 = Digest::SHA1.hexdigest(File.read(filepath, mode: 'rb'))
          average_sec = @transport.sync_call(:query_spec_average_sec, taskset_class, spec_sha1)
          if average_sec == nil
            average_sec = @unknown_spec_timeout_sec
          elsif average_sec < least_timeout_sec
            average_sec = least_timeout_sec
          end

          [
            spec_path,
            spec_sha1,
            average_sec * HARD_TIMEOUT_MULTIPLIER,
            average_sec * SOFT_TIMEOUT_MULTIPLIER,
          ]
        end
      end
    end
  end
end
