RRRSpec.configure(:client) do |config|
  config.master_url = 'http://localhost:9999'

  config.packaging_dir = File.expand_path("..", __FILE__)
  config.rsync_remote_path = "localhost:#{File.expand_path("../tmp/server-rsync", __FILE__)}"
  config.rsync_options = '--compress --times --recursive --links --perms --inplace --delete --exclude=tmp'
  config.unknown_spec_timeout_sec = 5
  config.least_timeout_sec = 5
  config.average_multiplier = 3
  config.hard_timeout_margin_sec = 10

  config.setup_command = "bundle install"
  config.slave_command = "bundle exec rrrspec-slave"
  config.worker_type = 'default'
  config.taskset_class = 'rrrspec'
  config.max_workers = 3
  config.max_trials = 3
  config.spec_files = ['spec/success_spec.rb', 'spec/fail_spec.rb', 'spec/timeout_spec.rb']
end
