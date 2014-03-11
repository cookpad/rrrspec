module RRRSpec
  module Server
    class JSONRPCTransport
      def initialize(handler)
        @handler = handler
      end

      protected

      def process_request(request)
        begin
          result = @handler.send(request['method'], self, *request['params'])
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

    class WebsocketTransport < JSONRPCTransport
      def initialize(handler, ws)
        super(handler)
        @ws = ws
        @message_id = 0
        @waitings = Hash.new

        ws.on(:open) do |event|
          @handler.open(self)
        end

        ws.on(:message) do |event|
          response = call_handler(MultiJson.load(event.data))
          if response
            ws.send(response)
          end
        end

        ws.on(:close) do |event|
          @handler.close(self)
        end
      end

      def rack_response
        @ws.rack_response
      end

      def send(method, **params)
        @ws.send(MultiJson.dump(method: method, params: params, id: nil))
      end

      def sync_call(method, **params)
        message_id = (@message_id += 1)
        @waitings[message_id] = Fiber.current
        @ws.send(MultiJson.dump(method: method, params: params, id: message_id))
        result, err = Fiber.yield
        raise err if err.present?
        result
      end

      private

      def call_handler(data)
        if data.include?('result')
          process_response(data)
        else
          process_request(data)
        end
      end

      def process_response(response)
        fiber = @waitings.delete(response['id'])
        if fiber
          fiber.yield(response['result'], response['error'])
        end
      end
    end

    class HTTPPostTransport < JSONRPCTransport
      def initialize(handler, env)
        super(handler)
        @request = Rack::Request.new(env)
      end

      def rack_response
        unless @request.post?
          [
            405,
            {'Content-Type' => 'text/plain'},
            ['Use POST'],
          ]
        else
          [
            200,
            {'Content-Type' => 'application/json'},
            [process_request(MultiJson.load(@request.body))],
          ]
        end
      end
    end
  end
end
