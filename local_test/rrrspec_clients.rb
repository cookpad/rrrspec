RRRSpec.configure(:client) do |conf|
  conf.rsync_remote_path = "localhost:#{File.expand_path("../tmp/server-rsync", __FILE__)}"
  conf.rsync_options = [
    '--compress',
    '--times',
    '--recursive',
    '--links',
    '--perms',
    '--inplace',
    '--delete',
    '--exclude=tmp',
  ].flatten.join(' ')
  conf.packaging_dir = File.expand_path("..", __FILE__)
  conf.spec_files = lambda do
    [
      'success_spec.rb',
      'fail_spec.rb',
      'timeout_spec.rb',
    ]
  end
  conf.setup_command = <<-END
    bundle install
  END
  conf.slave_command = <<-END
    bundle exec rrrspec-client slave
  END
  conf.worker_type = 'default'
  conf.taskset_class = 'rrrspec'
  conf.max_workers = 3
  conf.max_trials = 3
  conf.unknown_spec_timeout_sec = 5
  conf.least_timeout_sec = 5
end

RRRSpec.configure do |conf|
  conf.redis = { host: 'localhost', port: 9998 }
end
