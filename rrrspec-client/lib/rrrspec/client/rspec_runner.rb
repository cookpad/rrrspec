require 'rspec'
require 'rspec/core/formatters/base_text_formatter'

module RRRSpec
  module Client
    class RSpecRunner
      def initialize
        @options = RSpec::Core::ConfigurationOptions.new([])
        @options.parse_options
        @configuration = RSpec.configuration
        @configuration.setup_load_path_and_require([])
        @world = RSpec.world
        @before_suite_run = false
      end

      def exc_safe_replace_stdouts
        outbuf = ''
        errbuf = ''
        $stdout = StringIO.new(outbuf)
        $stderr = StringIO.new(errbuf)
        begin
          yield
        rescue Exception
          $stdout.puts $!
          $stdout.puts $!.backtrace.join("\n")
        end
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
            @configuration.files_to_run = [filepath]
            @configuration.load_spec_files
            @world.announce_filters
            unless @before_suite_run
              @configuration.run_hook(:before, :suite)
              @before_suite_run = true
            end
            status = true
          rescue Exception
            $stdout.puts $!
            $stdout.puts $!.backtrace.join("\n")
            status = false
          end
        end

        [outbuf, errbuf, status]
      end

      def run(*formatters)
        status = false
        outbuf, errbuf = exc_safe_replace_stdouts do
          @configuration.formatters << RSpec::Core::Formatters::BaseTextFormatter.new($stdout)
          formatters.each do |formatter|
            @configuration.formatters << formatter
          end
          @configuration.reporter.report(
            @world.example_count,
            @configuration.randomize? ? @configuration.seed : nil
          ) do |reporter|
            @world.example_groups.ordered.each do |example_group|
              example_group.run(reporter)
            end
          end
          status = true
        end

        [outbuf, errbuf, status]
      end

      def reset
        @world.example_groups.clear
        @configuration.reset
      end
    end
  end
end
