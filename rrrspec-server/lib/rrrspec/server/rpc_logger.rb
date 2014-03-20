module RRRSpec
  module Server
    class RPCLogger
      def initialize(transport, method, ref)
        @transport = transport
        @method = method
        @ref = ref
      end

      def write(string)
        now = Time.zone.now
        @transport.send(@method, @ref, now.strftime("%F %T ") + string + "\n")
      end
    end
  end
end
