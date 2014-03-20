module RRRSpec
  class JSONRPCTransport
    def self.compose_message(method, params, message_id)
      MultiJson.dump(method: method, params: params, id: message_id)
    end

    def initialize(handler, throw_exception: false)
      @handler = handler
      @throw_exception = throw_exception
    end

    protected

    def process_request(request)
      begin
        result = @handler.__send__(request['method'], self, *request['params'])
        if request['id']
          MultiJson.dump({result: result, error: nil, id: request['id']})
        else
          nil
        end
      rescue Exception => e
        if @throw_exception || !request['id']
          raise
        else
          RRRSpec.logger.fatal(e.message)
          RRRSpec.logger.fatal(e.backtrace.join("\n"))
          MultiJson.dump({result: nil, error: e.message, id: request['id']})
        end
      end
    end
  end

  class WebSocketTransport < JSONRPCTransport
    PING_INTERVAL_SEC = 15
    RETRY_INTERVAL_SEC = 1

    def initialize(handler, ws_or_url, throw_exception: false, auto_reconnect: false)
      super(handler, throw_exception: throw_exception)
      @message_id = 0
      @waitings = Hash.new
      @auto_reconnect = auto_reconnect

      if ws_or_url.is_a?(String)
        @initial_connection = true
        @url = ws_or_url
        setup_websocket(Faye::WebSocket::Client.new(@url, nil, ping: PING_INTERVAL_SEC))
      else
        @url = nil
        setup_websocket(ws_or_url)
      end
    end

    def setup_websocket(ws)
      @ws = ws

      @ws.on(:open) do |event|
        @initial_connection = false
        RRRSpec.logger.info("Connection opened: #{@ws}")
        Fiber.new do
          @handler.open(self)
        end.resume
      end

      @ws.on(:message) do |event|
        Fiber.new do
          RRRSpec.logger.info("Received: #{event.data}")
          response = call_handler(MultiJson.load(event.data))
          RRRSpec.logger.info("Response: #{response}")
          if response
            @ws.send(response)
          end
        end.resume
      end

      @ws.on(:close) do |event|
        RRRSpec.logger.info("Connection closed: #{@ws}")
        if @url && @auto_reconnect && @initial_connection
          sleep RETRY_INTERVAL_SEC
          setup_websocket(Faye::WebSocket::Client.new(@url, nil, ping: PING_INTERVAL_SEC))
        else
          Fiber.new do
            @handler.close(self)
          end.resume
        end
      end
    end

    def rack_response
      @ws.rack_response
    end

    def close
      @auto_reconnect = false
      @ws.close
    end

    def send(method, *params)
      direct_send(JSONRPCTransport.compose_message(method, params, nil))
    end

    def sync_call(method, *params)
      message_id = (@message_id += 1)
      @waitings[message_id] = Fiber.current
      direct_send(JSONRPCTransport.compose_message(method, params, message_id))
      result, err = Fiber.yield
      raise err if err.present?
      result
    end

    def direct_send(message)
      RRRSpec.logger.info("Sent:     #{message}")
      @ws.send(message)
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
        fiber.resume(response['result'], response['error'])
      end
    end
  end

  class HTTPPostTransport < JSONRPCTransport
    def initialize(handler, env, throw_exception: false)
      super(handler, throw_exception: throw_exception)
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

  class HTTPPostClient
    def initialize
      @conn = Faradday.new(url: RRRSpec.config.master_url)
    end

    def sync_call(method, *params)
      response = MultiJson.load(@conn.post do |req|
        req.url '/'
        req.headers['Content-Type'] = 'application/json'
        req.body = JSONRPCTransport.compose_message(method, params, 0)
      end.body)

      raise response['error'] if response['error'].present?
      response['result']
    end
  end
end
