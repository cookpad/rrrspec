require 'rrrspec/client/rspec_runner'

module RRRSpec
  module Client
    class RSpecRunnerFactory

      def create
        return RSpecRunner.new
      end

    end
  end
end
