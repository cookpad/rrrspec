require 'rrrspec/client'
require 'launchy'
require 'thor'

module RRRSpec
  module Client
    class CLI < Thor
      WAIT_POLLING_SEC = 10

      package_name 'RRRSpec'
      default_command 'help'
      class_option :config, aliases: '-c',  type: :string, default: ''

      no_commands do
        def setup(conf)
          RRRSpec.setup(conf, options[:config].split(':'))
        end

        def log_exception
          yield
        rescue
          RRRSpec.logger.error($!)
          raise
        end
      end

      option :'key-only', type: :boolean
      option :'rsync-name', type: :string, default: ENV['USER']
      option :'worker-type', type: :string
      option :max_workers, type: :numeric, desc: 'Overwrite max_workers configuration'
      desc 'start', 'start RRRSpec'
      def start
        setup(ClientConfiguration.new)
        if options[:'worker-type']
          RRRSpec.configuration.worker_type = options[:'worker-type']
        end
        if options[:max_workers]
          RRRSpec.configuration.max_workers = options[:max_workers]
        end
        taskset = Support.start_taskset(RRRSpec.configuration, options[:'rsync-name'])
        puts taskset.key

        if RRRSpec.configuration.rrrspec_web_base && !options[:'key-only']
          url = "#{RRRSpec.configuration.rrrspec_web_base}/tasksets/#{taskset.key}"
          Launchy.open(url)
        end
      end

      desc 'cancel', 'cancel the taskset'
      def cancel(taskset_id)
        setup(Configuration.new)
        taskset = Taskset.new(taskset_id)
        exit(1) unless taskset.exist?
        taskset.cancel
      end

      desc 'cancelall', 'cancel all tasksets whose rsync name is specified name'
      def cancelall(rsync_name)
        setup(Configuration.new)
        ActiveTaskset.all_tasksets_of(rsync_name).each do |taskset|
          taskset.cancel
        end
      end

      desc 'actives', 'list up the active tasksets'
      def actives
        setup(Configuration.new)
        ActiveTaskset.list.each { |taskset| puts taskset.key }
      end

      desc 'nodes', 'list up the active nodes'
      def nodes
        setup(Configuration.new)
        puts "Workers:"
        workers = Hash.new { |h, k| h[k] = [] }
        Worker.list.each do |worker|
          workers[worker.worker_type] << worker.key
        end
        workers.keys.sort.each do |k|
          puts "  #{k}:"
          workers[k].sort.each do |name|
            puts "    #{name}"
          end
        end
      end

      option :pollsec, type: :numeric, default: WAIT_POLLING_SEC
      desc 'waitfor', 'wait for the taskset'
      def waitfor(taskset_id)
        setup(Configuration.new)
        taskset = Taskset.new(taskset_id)
        exit(1) unless taskset.exist?

        rd, wt = IO.pipe

        cancelled = false
        do_cancel = proc {
          exit(1) if cancelled

          $stderr.puts "Cancelling taskset... (will force quit on next signal)"
          wt.write '1'
          cancelled = true
        }
        Signal.trap(:TERM, do_cancel)
        Signal.trap(:INT, do_cancel)

        loop do
          rs, ws, = IO.select([rd], [], [], options[:pollsec])
          if rs == nil
            break if taskset.persisted?
          elsif rs.size != 0
            rs[0].getc
            taskset.cancel
            break
          end
        end
      end

      option :'failure-exit-code', type: :numeric, default: 1
      option :verbose, type: :boolean, default: false
      option :'show-errors', type: :boolean, default: false
      desc 'show', 'show the result of the taskset'
      def show(taskset_id)
        setup(Configuration.new)
        taskset = Taskset.new(taskset_id)
        exit 1 unless taskset.exist?
        Support.show_result(taskset, options[:verbose], options[:'show-errors'])

        if taskset.status != 'succeeded'
          exit options[:'failure-exit-code']
        end
      end

      desc 'slave', 'run RRRSpec as a slave'
      def slave(working_dir=nil, taskset_key=nil)
        $0 = "rrrspec slave[#{ENV['SLAVE_NUMBER']}]"
        working_dir ||= ENV['RRRSPEC_WORKING_DIR']
        taskset_key ||= ENV['RRRSPEC_TASKSET_KEY']
        exit 1 unless taskset_key && working_dir

        setup(Configuration.new)
        log_exception do
          slave = Slave.create
          slave_runner = SlaveRunner.new(slave, working_dir, taskset_key)
          Thread.abort_on_exception = true
          Thread.fork { RRRSpec.pacemaker(slave, 60, 5) }
          Thread.fork { slave_runner.work_loop }
          Kernel.sleep
        end
      end
    end
  end
end
