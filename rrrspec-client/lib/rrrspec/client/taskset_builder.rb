module RRRSpec
  module Client
    class TasksetBuilder
      attr_accessor :packaging_dir
      attr_accessor :rsync_remote_path, :rsync_options
      attr_accessor :unknown_spec_timeout_sec, :least_timeout_sec
      attr_accessor :average_multiplier, :hard_timeout_margin_sec

      attr_accessor :rsync_name
      attr_accessor :setup_command, :slave_command
      attr_accessor :worker_type, :taskset_class, :max_workers, :max_trials
      attr_accessor :spec_files

      def initialize(transport)
        @transport = transport
      end

      def create_and_start
        taskset_ref = @transport.sync_call(
          :create_taskset,
          rsync_name,
          setup_command,
          slave_command,
          worker_type,
          taskset_class,
          max_workers,
          max_trials,
          task_argument,
        )
        if rsync_package
          @transport.sync_call(:dispatch_taskset, taskset_ref)
          taskset_ref
        else
          @transport.sync_call(:cancel_taskset, taskset_ref)
          raise "RSync Failed"
        end
      end

      private

      def task_argument
        spec_files.map do |spec_path|
          filepath = File.join(packaging_dir, spec_path)
          raise "Spec file not found: #{spec_path}" unless File.exists?(filepath)
          spec_sha1 = Digest::SHA1.hexdigest(File.read(filepath, mode: 'rb'))
          average_sec = @transport.sync_call(:query_spec_average_sec, taskset_class, spec_sha1)
          if average_sec == nil
            soft_timeout_sec = unknown_spec_timeout_sec
          elsif average_sec < least_timeout_sec
            soft_timeout_sec = least_timeout_sec
          else
            soft_timeout_sec = average_sec * average_multiplier
          end

          [spec_path, spec_sha1, soft_timeout_sec + hard_timeout_margin_sec, soft_timeout_sec]
        end
      end

      def rsync_package
        remote_path = File.join(rsync_remote_path, rsync_name)
        command = "rsync #{rsync_options} #{packaging_dir}/ #{remote_path}"
        RRRSpec.logger.info("Run RSync: #{command}")
        system(command)
        $?.success?
      end
    end
  end
end
