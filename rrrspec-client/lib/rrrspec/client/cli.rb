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
      end

      option :'key-only', type: :boolean
      option :'rsync-name', type: :string, default: ENV['USER']
      option :'worker-type', type: :string
      desc 'start', 'start RRRSpec'
      def start
        setup(ClientConfiguration.new)
        if options[:'worker-type']
          RRRSpec.configuration.worker_type = options[:'worker-type']
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
        Worker.list.each { |worker| puts "\t#{worker.key}" }
      end

      option :pollsec, type: :numeric, default: WAIT_POLLING_SEC
      desc 'waitfor', 'wait for the taskset'
      def waitfor(taskset_id)
        setup(Configuration.new)
        taskset = Taskset.new(taskset_id)
        exit(1) unless taskset.exist?

        rd, wt = IO.pipe
        Signal.trap(:TERM) { wt.write("1") }
        Signal.trap(:INT) { wt.write("1") }

        loop do
          rs, ws, = IO.select([rd], [], [], options[:pollsec])
          if rs == nil
            break if taskset.persisted?
          elsif rs.size != 0
            rs[0].getc
            taskset.cancel
          end
        end
      end

      option :'failure-exit-code', type: :numeric, default: 1
      option :verbose, type: :boolean, default: false
      desc 'show', 'show the result of the taskset'
      def show(taskset_id)
        setup(Configuration.new)
        taskset = Taskset.new(taskset_id)
        exit 1 unless taskset.exist?
        Support.show_result(taskset, options[:verbose])

        if taskset.status != 'succeeded'
          exit options[:'failure-exit-code']
        end
      end
    end
  end
end
