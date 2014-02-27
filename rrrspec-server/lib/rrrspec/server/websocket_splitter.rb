require 'multi_json'

module RRRSpec
  module Server
    class WebsocketSplitter
      def initialize(handler)
        @handler = handler
      end

      def call(env)
        if Feye::Websocket.websocket?(env)
          ws = Feye::Websocket.new(env)

          ws.on :message do |event|
            response = call_handler(event.data, ws)
            if response
              ws.send(response)
            end
          end

          ws.on :close do |event|
            @handler.close(ws)
          end

          ws.rack_response
        else
          request = Rack::Request.new(env)
          unless request.post?
            [
              405,
              {'Content-Type' => 'text/plain'},
              ['Use POST'],
            ] 
          else
            [
              200,
              {'Content-Type' => 'application/json'},
              [call_handler(request.body)],
            ]
          end
        end
      end

      def call_handler(data, ws=nil)
        request = MultiJson.load(data)
        begin
          result = @handler.send(request['method'], ws, *request['params'])
          if request['id']
            MultiJson.dump({result: result, error: nil, id: request['id']})
          else
            nil
          end
        rescue Exception => e
          if request['id']
            MultiJson.dump({result: nil, error: e.message, id: request['id']})
          else
            raise
          end
        end
      end
    end
  end
end
