module RRRSpec
  module Client
    module Support
      module_function

      def start_taskset(conf, rsync_name)
        $stderr.puts '1/3) Start rsync...'
        if is_using_rsync?(rsync_name)
          $stderr.puts 'It seems you are running rrrspec already'
          $stderr.puts 'Please wait until the previous run finishes'
          exit 1
        end
        unless run_rsync_package(rsync_name)
          $stderr.puts 'rsync failed.'
          exit 1
        end

        $stderr.puts '2/3) Creating a new taskset...'
        taskset = Taskset.create(
          rsync_name,
          conf.setup_command,
          conf.slave_command,
          conf.worker_type,
          conf.taskset_class,
          conf.max_workers,
          conf.max_trials,
          conf.unknown_spec_timeout_sec,
          conf.least_timeout_sec
        )
        estimate_sec_sorted(conf.taskset_class, conf.spec_files.uniq).reverse_each do |spec_file, estimate_sec|
          task = Task.create(taskset, estimate_sec, spec_file)
          taskset.add_task(task)
          taskset.enqueue_task(task)
        end

        $stderr.puts '3/3) Enqueue the taskset...'
        ActiveTaskset.add(taskset)
        DispatcherQueue.notify
        $stderr.puts 'Your request is successfully enqueued!'
        return taskset
      end

      def show_result(taskset, verbose=false, show_errors=false)
        if show_errors
          puts "Failed Tasks:\n\n"
          taskset.tasks.each do |task|
            if task.status == "failed"
              trial = task.trials.detect { |t| t.status == "failed" }
              stdout = trial.stdout
              puts "Task: #{task.spec_file}\n\n"
              unless stdout.blank?
                puts "\tSTDOUT:"
                stdout.each_line { |line| puts "\t#{line}" }
              end
              stderr = trial.stderr
              unless stderr.blank?
                puts "STDERR:"
                stderr.each_line { |line| puts "\t#{line}" }
              end
              puts "\n"
            end
          end
          puts
        end

        puts "Status:    #{taskset.status}"
        puts "Created:   #{taskset.created_at}"
        puts "Finished:  #{taskset.finished_at}"
        puts "Tasks:     #{taskset.task_size}"
        puts "Succeeded: #{taskset.succeeded_count}"
        puts "Failed:    #{taskset.failed_count}"

        if verbose
          puts

          puts "Log:"
          taskset.log.each_line { |line| puts "\t#{line}" }
          puts

          puts "Workers:"
          taskset.worker_logs.each do |worker_log|
            puts "\tKey: #{worker_log.key}"
            puts "\tStarted:        #{worker_log.started_at}"
            puts "\tRSync Finished: #{worker_log.rsync_finished_at}"
            puts "\tSetup Finished: #{worker_log.setup_finished_at}"
            puts "\tFinished:       #{worker_log.finished_at}"
            puts "\tLog:"
            worker_log.log.each_line { |line| puts "\t\t#{line}" }
          end
          puts

          puts "Slaves:"
          taskset.slaves.each do |slave|
            puts "\tKey:    #{slave.key}"
            puts "\tStatus: #{slave.status}"
            puts "\tTrials:"
            slave.trials.each do |trial|
              puts "\t\t#{trial.key}"
            end
            puts "\tLog:"
            slave.log.each_line { |line| puts "\t\t#{line}" }
          end
          puts

          puts "Tasks:"
          taskset.tasks.each do |task|
            puts "\tKey:    #{task.key}"
            puts "\tSpec:   #{task.spec_file}"
            puts "\tStatus: #{task.status}"
            puts "\tTrials:"
            task.trials.each do |trial|
              puts "\t\tKey:      #{trial.key}"
              puts "\t\tSlave:    #{trial.slave.key}"
              puts "\t\tStatus:   #{trial.status}"
              puts "\t\tStarted:  #{trial.started_at}"
              puts "\t\tFinished: #{trial.finished_at}"
              puts "\t\tPassed:   #{trial.passed}"
              puts "\t\tPending:  #{trial.pending}"
              puts "\t\tFailed:   #{trial.failed}"
              stdout = trial.stdout
              if stdout
                puts "\t\tSTDOUT:"
                stdout.each_line { |line| puts "\t\t\t#{line}" }
              end
              stderr = trial.stderr
              if stderr
                puts "\t\tSTDERR:"
                stderr.each_line { |line| puts "\t\t\t#{line}" }
              end
            end
          end
        end
      end

      def run_rsync_package(rsync_name)
        conf = RRRSpec.configuration
        remote_path = File.join(conf.rsync_remote_path, rsync_name)
        command = "rsync #{conf.rsync_options} #{conf.packaging_dir}/ #{remote_path}"
        $stderr.puts command
        system(command)
        $?.success?
      end

      def is_using_rsync?(rsync_name)
        ActiveTaskset.list.any? do |taskset|
          taskset.rsync_name == rsync_name
        end
      end

      # Public: Sort the spec filepaths by their estiamted spec execution times.
      #
      # Returns an array of [spec_file, estiamte_sec]
      def estimate_sec_sorted(taskset_class, spec_files)
        estimate_secs = TasksetEstimation.estimate_secs(taskset_class)
        spec_files.map do |spec_file|
          [spec_file, estimate_secs[spec_file]]
        end.sort do |a, b|
          case
          when a[1] == nil && b[1] == nil then 0
          when a[1] == nil && b[1] != nil then 1
          when a[1] != nil && b[1] == nil then -1
          else a[1] - b[1]
          end
        end
      end
    end
  end
end
