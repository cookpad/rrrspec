require 'fileutils'

RRRSpec.configure do |conf|
  conf.redis = {
    host: ENV['REDIS_HOST'],
  }
end

RRRSpec.configure(:server) do |conf|
  RRRSpec.logger = Logger.new($stderr)
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
  log_texts_path = '/tmp/rrrspec-log-texts'
  FileUtils.mkdir_p(log_texts_path)
  conf.execute_log_text_path = log_texts_path
end
