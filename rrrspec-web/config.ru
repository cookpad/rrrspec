require 'rrrspec/web'

RRRSpec.configure do |conf|
  conf.redis = {
    host: ENV['REDIS_HOST'],
  }
end

RRRSpec.configure(:web) do |conf|
  conf.persistence_db = {
    adapter: 'mysql2',
    encoding: 'utf8mb4',
    charset: 'utf8mb4',
    collation: 'utf8mb4_general_ci',
    database: 'rrrspec',
    username: 'root',
    password: ENV['DB_PASSWORD'],
    host: ENV['DB_HOST'],
  }
  conf.execute_log_text_path = '/tmp/rrrspec-log-texts'
end

RRRSpec::Web.setup

run Rack::Cascade.new([RRRSpec::Web::APIv2, RRRSpec::Web::App])
