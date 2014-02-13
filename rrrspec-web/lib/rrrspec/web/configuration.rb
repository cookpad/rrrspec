module RRRSpec
  module Web
    class WebConfiguration < RRRSpec::Configuration
      attr_accessor :persistence_db

      def initialize
        super()
        @type = :web
      end
    end
  end
end
