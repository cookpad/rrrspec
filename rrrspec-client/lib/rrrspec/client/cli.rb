module RRRSpec
  module Client
    class CLIAPIHandler
      def initialize(command, options)
        @command = command
        @options = options
      end

      def open(transport)
      end

      def close(transport)
        EM.stop_event_loop
      end

      def start(transport)
        rsync_name = @options[:rsync_name] || RRRSpec.config.rsync_name || ENV['USER']
        worker_type = @options[:worker_type] || RRRSpec.config.worker_type

        taskset_ref = TasksetBuilder.build_and_start(
          transport,
          rsync_name,
          RRRSpec.config.setup_command,
          RRRSpec.config.slave_command,
          worker_type,
          RRRSpec.config.taskset_class,
          RRRSpec.config.max_workers,
          RRRSpec.config.max_trials,
          RRRSpec.config.tasks
        )
        puts taskset_ref[1]
        transport.close
      end

      def cancel(transport)
        taskset_id = ARGV.shift
        if taskset_id
          taskset_ref = [:taskset, taskset_id]
          transport.send(:cancel_taskset, taskset_ref)
          transport.close
        else
          raise "Specify the taskset id"
        end
      end

      def cancelall(transport)
        rsync_name = ARGV.shift
        if rsync_name
          transport.send(:cancel_user_taskset, rsync_name)
          transport.close
        else
          raise "Specify the rsync name"
        end
      end

      def actives(transport)
        # TODO
        transport.close
      end

      def nodes(transport)
        # TODO
        transport.close
      end

      def waitfor(transport)
        taskset_id = ARGV.shift
        if taskset_id
          @exit_if_taskset_finished = true
          taskset_ref = [:taskset, taskset_id]
          transport.sync_call(:listen_to_taskset, taskset_ref)
          status = transport.sync_call(:query_taskset_status, taskset_ref)
          if ['cancelled', 'failed', 'succeeded'].include?(status)
            transport.close
          end
        else
          raise "Specify the taskset id"
        end
      end

      def show(transport)
        # TODO
        transport.close
      end

      def taskset_updated(transport, timestamp, taskset_ref, h)
        if @exit_if_taskset_finished && h[:finished_at].present?
          tranport.close
        end
      end

      def task_updated(transport, timestamp, task_ref, h)
        # Do nothing
      end

      def trial_created(transport, timestamp, trials_ref, task_ref, slave_ref, created_at)
        # Do nothing
      end

      def trial_updated(transport, timestamp, trial_ref, task_ref, finished_at, trial_status, passed, pending, failed)
        # Do nothing
      end

      def worker_log_created(transport, timestamp, worker_log_ref, worker_name)
        # Do nothing
      end

      def worker_log_updated(transport, timestamp, worker_log_ref, h)
        # Do nothing
      end

      def slave_created(transport, timestamp, slave_ref, slave_name)
        # Do nothing
      end

      def slave_updated(transport, timestamp, slave_ref, h)
        # Do nothing
      end
    end

    module CLI
      COMMANDS = {
        'start' => 'start RRRSpec',
        'cancel' => 'cancel the taskset',
        'cancelall' => 'cancel all tasksets whose rsync name is specified name',
        'actives' => 'list up the active tasksets',
        'nodes' => 'list up the active nodes',
        'waitfor' => 'wait for the taskset',
        'show' => 'show the result of the taskset',
      }

      module_function

      def run
        options, command, command_options = parse_options
        setup(options)

        if COMMANDS.include?(command)
          EM.run do
            Fiber.new do
              WebSocketTransport.new(
                CLICommandHandler.new(command, command_options),
                Faye::Websocket::Client.new(RRRSpec.config.master_url),
              )
            end.resume
          end
        else
          nocommand(command)
        end
      end

      def parse_options
        options = {}
        command = nil
        command_options = {}

        OptionParser.new do |opts|
          opts.on('-c', '--config FILE') { |file| options[:config] = file }
        end.order!

        command = ARGV.shift
        case command
        when 'start'
          OptionParser.new do |opts|
            opts.on('--key-only') { |v| command_options[:key_only] = v }
            opts.on('--rsync-name NAME') { |name| command_options[:rsync_name] = name }
            opts.on('--worker-type TYPE') { |type| command_options[:worker_type] = type }
          end.order!
        when 'cancel'
        when 'cancelall'
        when 'actives'
        when 'nodes'
        when 'waitfor'
        when 'show'
          OptionParser.new do |opts|
            opts.on('--failure-exit-code N', OptionParser::DecimalInteger) do |n|
              command_options[:failure_exit_code] = n
            end
          end.order!
        end

        return options, command, command_options
      end

      def setup(options)
        RRRSpec.application_type = :client
        RRRSpec.config = ClientConfig.new
        files = if options[:config].present?
                  [options[:config]]
                else
                  ['.rrrspec', '.rrrspec-local', File.expand_path('~/.rrrspec')]
                end
        files.each do |path|
          load(path) if File.exists?(path)
        end
      end

      def nocommand(command)
      end
    end
  end
end
