require 'rack/test'

class TestTransport
  def initialize(app)
    @session = Rack::Test::Session.new(Rack::MockSession.new(app))
  end

  def sync_call(method, *params)
    @session.post('/', MultiJson.dump(method: method, params: params, id: 1))
    response = MultiJson.load(@session.last_response.body)
    raise response['error'] if response['error'].present?
    response['result']
  end

  alias :send :sync_call
end

module TestTransportHelper
  def master_transport
    @master_transport ||= TestTransport.new(
      RRRSpec::Server::WebSocketSplitter.new(RRRSpec::Server::MasterAPIHandler.new, true)
    )
  end
end
