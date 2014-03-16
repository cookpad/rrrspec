module RRRSpec
  module Server
    class WebSocketSplitter
      def initialize(handler, throw_exception: false)
        @handler = handler
        @throw_exception = throw_exception
      end

      def call(env)
        if Faye::WebSocket.websocket?(env)
          WebSocketTransport.new(
            @handler,
            Faye::WebSocket.new(env, ping: WebSocketTransport::PING_INTERVAL_SEC),
            throw_exception: @throw_exception,
          ).rack_response
        else
          HTTPPostTransport.new(@handler, env, throw_exception: @throw_exception).rack_response
        end
      end
    end
  end
end
