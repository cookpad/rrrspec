RRRSpec.configure(:server) do |conf|
  RRRSpec.logger = Logger.new(File.expand_path("../tmp/server.log", __FILE__))
  RRRSpec.logger.formatter = Logger::Formatter.new
  conf.rsync_server = 'localhost'
  conf.rsync_dir = File.expand_path("../tmp/server-rsync", __FILE__)
  conf.rsync_options = %w(
    --compress
    --times
    --recursive
    --links
    --perms
    --inplace
    --delete
  ).join(' ')
  conf.persistence_db = {
    adapter: 'sqlite3',
    database: File.expand_path("../tmp/local_test.db", __FILE__)
  }
  conf.execute_log_text_path = File.expand_path("../tmp/log_files", __FILE__)
end

RRRSpec.configure(:worker) do |conf|
  RRRSpec.logger = Logger.new(File.expand_path("../tmp/worker.log", __FILE__))
  RRRSpec.logger.formatter = Logger::Formatter.new
  conf.worker_type = 'default'
  conf.working_dir = File.expand_path("../tmp/worker/working", __FILE__)
end

RRRSpec.configure do |conf|
  conf.redis = { host: 'localhost', port: 9998 }
end
