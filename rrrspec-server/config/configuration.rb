Time.zone_default = Time.find_zone('Asia/Tokyo')

RRRSpec.configure(:master) do |config|
  ActiveRecord::Base.default_timezone = :local
  config.redis = { url: 'http://localhost' }
  config.execute_log_text_path = '...'
  config.json_cache_path = '...'
end

RRRSpec.configure(:worker) do |config|
  config.master_url = 'http://master.local'
  config.rsync_remote_path = '...'
  config.rsync_options = '...'
  config.working_dir = '...'
  config.worker_type = '...'
  config.slave_processes = '...'
end
