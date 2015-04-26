RRRSpec.configure do |conf|
  conf.redis = {
    host: ENV['REDIS_HOST'],
  }
end

RRRSpec.configure(:client) do |conf|
  conf.rsync_remote_path = "#{ENV['MASTER_HOST']}:/tmp/rrrspec-rsync"
  conf.rsync_options = [
    '--compress',
    '--times',
    '--recursive',
    '--links',
    '--perms',
    '--inplace',
    '--delete',
    '--exclude=tmp',
  ].join(' ')
  conf.packaging_dir = File.expand_path("../..", __FILE__)
  conf.spec_files = lambda do
    [
      'local_test/success_spec.rb',
      'local_test/fail_spec.rb',
      'local_test/timeout_spec.rb',
    ]
  end
  conf.setup_command = <<-END
    cd local_test
    bundle install
  END
  conf.slave_command = <<-END
    cd local_test
    bundle exec ../rrrspec-client/bin/rrrspec-client slave
  END
  conf.worker_type = 'default'
  conf.taskset_class = 'rrrspec/local_test'
  conf.max_workers = 3
  conf.max_trials = 3
  conf.unknown_spec_timeout_sec = 5
  conf.least_timeout_sec = 5
end
