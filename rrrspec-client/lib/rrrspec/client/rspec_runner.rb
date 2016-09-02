require 'rspec'
require 'rrrspec/client/base_text_formatter'

module RRRSpec
  module Client
    class RSpecRunner
      def initialize
        @options = RSpec::Core::ConfigurationOptions.new([])
        @configuration = RSpec.configuration
        @world = RSpec.world
        @before_suite_run = false
        @stdout_buffer = StringIO.new
        @stderr_buffer = StringIO.new
      end

      def exc_safe_replace_stdouts
        @stdout_buffer.string = ''
        @stderr_buffer.string = ''
        $stdout = @stdout_buffer
        $stderr = @stderr_buffer
        begin
          yield
        rescue Exception
          $stdout.puts $!
          $stdout.puts $!.backtrace.join("\n")
        end
        outbuf = @stdout_buffer.string
        errbuf = @stderr_buffer.string
        [outbuf, errbuf]
      ensure
        $stdout = STDOUT
        $stderr = STDERR
      end

      def setup(filepath)
        status = false
        outbuf, errbuf = exc_safe_replace_stdouts do
          begin
            @options.configure(@configuration)
            @configuration.output_stream = $stdout
            @configuration.error_stream = $stderr
            @configuration.add_formatter(BaseTextFormatter)
            @configuration.files_to_run = [filepath]
            @configuration.load_spec_files
            @world.announce_filters
            unless @before_suite_run
              run_before_suite_hooks
              @before_suite_run = true
            end
            status = true
          rescue Exception
            $stdout.puts $!
            $stdout.puts $!.backtrace.join("\n")
            status = false
          end
        end

        [status, outbuf, errbuf]
      end

      def run(*formatters)
        status = false
        outbuf, errbuf = exc_safe_replace_stdouts do
          formatters.each do |formatter|
            @configuration.add_formatter(formatter)
          end
          @configuration.reporter.report(@world.example_count) do |reporter|
            @world.ordered_example_groups.each do |example_group|
              example_group.run(reporter)
            end
          end
          status = true
        end

        [status, outbuf, errbuf]
      end

      def reset
        @world.example_groups.clear
        @configuration.reset
      end

      private

      def run_before_suite_hooks
        hooks = @configuration.instance_variable_get(:@before_suite_hooks)
        hook_context = RSpec::Core::SuiteHookContext.new
        hooks.each do |h|
          h.run(hook_context)
        end
      end
    end
  end
end
