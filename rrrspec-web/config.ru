require 'rrrspec/web'

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: "db/development.sqlite3")
ActiveRecord::Base.logger = Logger.new($stderr)

RRRSpec.config = RRRSpec::Web::WebConfig.new
RRRSpec.config.execute_log_text_path = 'tmp/log_text'

run Rack::Cascade.new([RRRSpec::Web::API.new, RRRSpec::Web::App.new])
