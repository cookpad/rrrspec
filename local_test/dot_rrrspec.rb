RRRSpec.configure(:client) do |config|
  config.master_url = 'http://localhost:9999'
  config.packaging_dir = File.expand_path("..", __FILE__)
  config.rsync_remote_path = "localhost:#{File.expand_path("../tmp/server-rsync", __FILE__)}"
  config.rsync_options = '--compress --times --recursive --links --perms --inplace --delete --exclude=tmp'
  config.spec_files = ['spec/success_spec.rb', 'spec/fail_spec.rb', 'spec/timeout_spec.rb']
  config.setup_command = "bundle install"
  config.slave_command = "bundle exec rrrspec-slave"
  config.taskset_class = 'rrrspec'
  config.worker_type = 'default'
  config.max_workers = 3
  config.max_trials = 3
  config.unknown_spec_timeout_sec = 5
  config.least_timeout_sec = 5
end
