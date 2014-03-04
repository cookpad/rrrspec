module RRRSpec
  module Server
    module SerializableCarrier
      extend ActiveSupport::Concern

      module ClassMethods
        def fields(*params)
          define_method(:initialize) do |opt|
            params.each do |param|
              if opt.key?(param)
                set_instance_variable("@#{param}", opt.delete(param))
              else
                raise ArgumentError
              end
            end
            unless opt.empty?
              raise ArgumentError
            end
          end

          define_method(:to_msgpack) do
            Hash[
              params.map do |param|
                [param, instance_variable_get("@#{param}")]
              end
            ].to_msgpack
          end
        end
      end
    end

    class RSyncInfo
      include SerializableCarrier
      fields :server, :options, :base_dir, :name
      attr_reader :name

      def transfer_command(transfer_to)
        "rsync #{@options} #{@server}:#{File.join(@base_dir, @name)}/ #{File.join(transfer_to, @name)}"
      end
    end

    module RSyncExecutor
      def self.rsync(logger, taskset, rsync_info)
        logger.write("Start RSync")

        working_path = RRRSpec.configuration.working_dir
        FileUtils.mkdir_p(working_path) unless Dir.exists?(working_path)
        remote_path = File.join(RRRSpec.configuration.rsync_remote_path, taskset.rsync_name)
        command = "rsync #{RRRSpec.configuration.rsync_options} #{remote_path}/ #{working_path}"

        pid, out_rd, err_rd = execute_with_logs(working_path, command, {})
        log_to_logger(logger, out_rd, err_rd)
        pid, status = Process.waitpid2(pid)
        if status.success?
          logger.write("RSync finished")
          return true
        else
          logger.write("RSync failed")
          ArbiterQueue.fail(taskset)
          return false
        end
      end
    end

    class WorkerRunner
      CANCEL_POLLING = 10
      TIMEOUT_EXITCODE = 42

      attr_reader :internal_status, :current_taskset

      def initialize(worker)
        @worker = worker
      end

      def work_loop
        loop do
          DispatcherQueue.notify
          work
        end
      end

      private


      def setup(logger, taskset)
        logger.write("Start setup")
        env = {
          'NUM_SLAVES' => RRRSpec.configuration.slave_processes.to_s
        }

        working_path = File.join(RRRSpec.configuration.working_dir, taskset.rsync_name)
        pid, out_rd, err_rd = execute_with_logs(working_path, '/bin/bash -ex', env,
                                                taskset.setup_command)
        log_to_logger(logger, out_rd, err_rd)
        pid, status = Process.waitpid2(pid)
        if status.success?
          logger.write("Setup finished")
          return true
        else
          logger.write("Setup failed")
          ArbiterQueue.fail(taskset)
          return false
        end
      end

      def rspec(taskset)
        working_path = File.join(RRRSpec.configuration.working_dir, taskset.rsync_name)

        num_slaves = RRRSpec.configuration.slave_processes
        env = {}
        env["NUM_SLAVES"] = num_slaves.to_s
        env["RRRSPEC_CONFIG_FILES"] = RRRSpec.configuration.loaded.join(':')
        env["RRRSPEC_WORKING_DIR"] = RRRSpec.configuration.working_dir
        env["RRRSPEC_TASKSET_KEY"] = taskset.key

        pid_to_slave_number = {}
        slave_command = taskset.slave_command
        spawner = proc do |slave_number|
          pid, out_rd, err_rd = execute_with_logs(
            working_path, '/bin/bash -ex',
            env.merge({"SLAVE_NUMBER" => slave_number.to_s}),
            slave_command
          )
          slave = Slave.build_from_pid(pid)
          taskset.add_slave(slave)
          Thread.fork { log_to_logger(TimedLogger.new(slave), out_rd, err_rd) }

          pid_to_slave_number[pid] = slave_number
        end

        num_slaves.times { |i| spawner.call(i) }

        cancel_watcher_pid = Process.fork do
          $0 = 'rrrspec cancel watcher'
          loop do
            break unless taskset.status == 'running'
            sleep CANCEL_POLLING
          end
        end

        trials = 1
        max_trials = taskset.max_trials
        loop do
          break if pid_to_slave_number.empty?
          begin
            pid, status = Process.wait2
            break if pid == cancel_watcher_pid
            break unless taskset.status == 'running'

            slave = Slave.build_from_pid(pid)
            if status.success?
              slave.update_status('normal_exit')
              pid_to_slave_number.delete(pid)
            else
              exit_code = (status.to_i >> 8)
              if exit_code == TIMEOUT_EXITCODE
                slave_log = slave.log
                slave.trials.each do |trial|
                  if trial.status == nil
                    trial.finish('timeout', slave_log, '', nil, nil, nil)
                    ArbiterQueue.trial(trial)
                  end
                end
                slave.update_status('timeout_exit')
              else
                slave.trials.each do |trial|
                  if trial.status == nil
                    trial.finish('error', '', '', nil, nil, nil)
                    ArbiterQueue.trial(trial)
                  end
                end
                slave.update_status('failure_exit')
                trials += 1
                if trials > max_trials
                  ArbiterQueue.fail(taskset)
                  break
                end
              end
              slave_number = pid_to_slave_number[pid]
              pid_to_slave_number.delete(pid)
              spawner.call(slave_number)
            end
          rescue Errno::ECHILD
            break
          end
        end
        return cancel_watcher_pid, pid_to_slave_number
      end

      def cleaning_process(logger, taskset, cancel_watcher_pid, pid_to_slave_number)
        logger.write("Send TERM signal to the children")
        (pid_to_slave_number.keys + [cancel_watcher_pid]).each do |pid|
          begin
            Process.kill("-TERM", pid)
          rescue Errno::ESRCH, Errno::EPERM
          end
        end

        logger.write("Wait for the children")
        begin
          loop do
            pid, status = Process.wait2
            if pid != cancel_watcher_pid
              slave = Slave.build_from_pid(pid)
              slave.update_status('normal_exit')
            end
          end
        rescue Errno::ECHILD
        end
        logger.write("Finished the task")

        # Some slaves are failed to exit with SIGTERM. Kill -9 them by name.
        `ps aux | grep "rrrspec slave" | grep -v grep | awk '{print $2}'`.split("\n").map(&:to_i).each do |pid|
          begin
            Process.kill("KILL", pid)
          rescue Errno::ESRCH, Errno::EPERM
          end
        end
      end

      def work
        @worker.update_current_taskset(nil)
        taskset = @worker.dequeue_taskset
        worker_log = WorkerLog.create(@worker, taskset)
        logger = TimedLogger.new(worker_log)

        check = proc do
          unless taskset.status == 'running'
            logger.write("The taskset(#{taskset.key}) is not running but #{taskset.status}")
            return
          end
        end
        check.call
        @worker.update_current_taskset(taskset)

        rsync(logger, taskset)
        worker_log.set_rsync_finished_time
        check.call

        setup(logger, taskset)
        worker_log.set_setup_finished_time
        check.call

        cancel_watcher_pid, pid_to_slave_number = rspec(taskset)
        cleaning_process(logger, taskset, cancel_watcher_pid, pid_to_slave_number)
      ensure
        worker_log.set_finished_time if worker_log
        @worker.update_current_taskset(nil)
      end

      def execute_with_logs(chdir, command, env, input=nil)
        Bundler.with_clean_env do
          in_rd, in_wt = IO.pipe
          out_rd, out_wt = IO.pipe
          err_rd, err_wt = IO.pipe
          pid = spawn(env, command, { chdir: chdir, pgroup: true,
                                      in: in_rd, out: out_wt, err: err_wt })
          out_wt.close_write
          err_wt.close_write
          in_wt.write(input) if input
          in_wt.close_write

          return pid, out_rd, err_rd
        end
      end

      def log_to_logger(logger, out_rd, err_rd)
        rds = [out_rd, err_rd]
        while !rds.empty?
          IO.select(rds)[0].each do |r|
            line = r.gets
            if line
              line = line.strip
              if r == out_rd
                logger.write("OUT " + line)
              else
                logger.write("ERR " + line)
              end
            else
              rds.delete(r)
            end
          end
        end
      end
    end
  end
end
