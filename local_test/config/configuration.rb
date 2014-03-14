RRRSpec.configure(:master) do |config|
  RRRSpec.logger = Logger.new(File.expand_path("../../tmp/server.log", __FILE__))
  RRRSpec.logger.formatter = Logger::Formatter.new

  config.port = 9999
  config.redis = { host: 'localhost', port: 9998 }
  config.execute_log_text_path = File.expand_path("../../tmp/log_files", __FILE__)
  config.json_cache_path = File.expand_path("../../tmp/api_cache", __FILE__)
end

RRRSpec.configure(:worker) do |config|
  RRRSpec.logger = Logger.new(File.expand_path("../../tmp/worker.log", __FILE__))
  RRRSpec.logger.formatter = Logger::Formatter.new

  config.master_url = "http://localhost:9999"
  config.rsync_remote_path = "localhost:#{File.expand_path("../../tmp/server-rsync", __FILE__)}"
  config.rsync_options = '--compress --times --recursive --links --perms --inplace --delete'
  config.working_dir = File.expand_path("../../tmp/worker/working", __FILE__)
  config.worker_type = 'default'
  config.slave_processes = 8
end
