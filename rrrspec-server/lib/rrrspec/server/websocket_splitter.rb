module RRRSpec
  module Server
    class WebsocketSplitter
      def initialize(handler)
        @handler = handler
      end

      def call(env)
        if Feye::Websocket.websocket?(env)
          WebsocketTransport.new(@handler, Feye::Websocket.new(env)).rack_response
        else
          HTTPPostTransport.new(@handler, env).rack_response
        end
      end
    end
  end
end
