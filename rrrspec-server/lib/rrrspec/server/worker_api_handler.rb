module RRRSpec
  module Server
    module CommandExecutor
      def self.batch(logger, *cmd, **opts)
        execute(logger, *cmd, **opts).value
      end

      def self.async(logger, *cmd, **opts)
        execute(logger, *cmd, **opts)
      end

      def self.execute(logger, *cmd, **opts)
        stdin_string = opts.delete(:stdin_text)
        stdin, stdout, stderr, wait_thr = Bundler.with_clean_env { Open3.popen3(*cmd, opts) }
        stdin.write(stdin_string) if stdin_string
        stdin.close
        Thread.fork do
          reads = [stdout, stderr]
          loop do
            break if reads.empty?
            IO.select(reads)[0].each do |r|
              line = r.gets
              if line
                logger.write("#{r == stdout ? "OUT" : "ERR"} #{line.strip}")
              else
                reads.delete(r)
              end
            end
          end
          wait_thr.value
        end
      end
    end

    class WorkerAPIHandler
      TIMEOUT_EXITCODE = 42
      HEARTBEAT_SEC = 55

      def initialize
        @timer = nil
        @shutdown = nil
        @current_taskset = nil
      end

      def open(transport)
        update_current_taskset(transport)
        @timer = EM.add_periodic_timer(HEARTBEAT_SEC) { update_current_taskset(transport) }
      end

      def close(transport)
        if @timer
          @timer.cancel
          @timer = nil
        end
        EM.stop_event_loop
      end

      def assign_taskset(transport, taskset_ref, rsync_name, setup_command, slave_command, max_trials)
        return nil if @current_taskset.present?

        worker_log_ref = transport.sync_call(:create_worker_log, RRRSpec.generate_worker_name, taskset_ref)
        logger = RPCLogger.new(transport, :append_worker_log_log, worker_log_ref)

        @current_taskset = taskset_ref
        update_current_taskset(transport)

        working_path = File.join(RRRSpec.config.working_dir, rsync_name)

        actions = {
          rsync: -> { rsync(logger, working_path,
                            RRRSpec.config.rsync_options,
                            RRRSpec.config.rsync_remote_path,
                            rsync_name) },
          setup: -> { setup(logger, working_path, setup_command) },
          rspec: -> { rspec(transport, logger, working_path, taskset_ref, slave_command, max_trials) },
        }

        [:rsync, :setup, :rspec].each do |action|
          logger.write("Start #{action}")
          transport.send("set_#{action}_finished_time", worker_log_ref)
          if actions[action].call
            logger.write("Finish #{action}")
          else
            logger.write("Fail #{action}")
            break
          end
          return nil if @shutdown
        end

        nil
      ensure
        @shutdown = false
        @current_taskset = nil
        update_current_taskset(transport)

        transport.send(:finish_worker_log, worker_log_ref) if worker_log_ref
      end

      def taskset_finished(transport, taskset_ref)
        if @current_taskset == taskset_ref
          @shutdown = true
        end
        nil
      end

      private

      def update_current_taskset(transport)
        transport.send(:current_taskset,
                       RRRSpec.generate_worker_name,
                       RRRSpec.config.worker_type,
                       @current_taskset)
      end

      def rsync(logger, working_path, rsync_options, rsync_remote_path, rsync_name)
        FileUtils.mkdir_p(working_path)
        CommandExecutor.batch(
          logger,
          "rsync #{rsync_options} #{File.join(rsync_remote_path, rsync_name)}/ #{working_path}",
          chdir: RRRSpec.config.working_dir,
        ).success?
      end

      def setup(logger, working_path, setup_command)
        CommandExecutor.batch(
          logger,
          { 'NUM_SLAVES' => RRRSpec.config.slave_processes.to_s },
          '/bin/bash -ex',
          chdir: working_path,
          stdin_text: setup_command,
        ).success?
      end

      def rspec(transport, logger, working_path, taskset_ref, slave_command, max_trials)
        trials = 1
        RRRSpec.config.slave_processes.times.map do |i|
          slave_number = i
          Thread.fork do
            loop do
              break if @shutdown
              uuid = SecureRandom.uuid
              status = CommandExecutor.batch(
                logger,
                {
                  'NUM_SLAVES' => RRRSpec.config.slave_processes.to_s,
                  'RRRSPEC_MASTER_URL' => RRRSpec.config.master_url,
                  'RRRSPEC_TASKSET_ID' => taskset_ref[1].to_s,
                  'RRRSPEC_WORKING_PATH' => working_path,
                  'RRRSPEC_SLAVE_UUID' => uuid,
                  'SLAVE_NUMBER' => slave_number.to_s,
                },
                '/bin/bash -ex',
                chdir: working_path,
                stdin_text: slave_command,
              )
              break if status.success?

              exit_code = (status.to_i >> 8)
              slave_status = (exit_code == TIMEOUT_EXITCODE) ? 'timeout_exit' : 'failure_exit'
              transport.send(:force_finish_slave, RRRSpec.generate_slave_name(uuid), slave_status)
              trials += 1
              if trials > max_trials
                @shutdown = true
                transport.send(:fail_taskset, taskset_ref)
              end
            end
          end
        end.each(&:join)
        true
      end
    end
  end
end
