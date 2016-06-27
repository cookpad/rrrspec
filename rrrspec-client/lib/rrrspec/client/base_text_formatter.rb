require 'rspec/core/formatters/base_text_formatter'

module RRRSpec
  module Client
    class BaseTextFormatter < RSpec::Core::Formatters::BaseTextFormatter
      RSpec::Core::Formatters.register(self, :message, :dump_summary, :dump_failures, :dump_pending, :seed)

      def close(_notification)
        # Do not close `output` .
      end
    end
  end
end
