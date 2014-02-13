RRRSpec.configure(:client) do |conf|
  conf.packaging_rsync_options = [
    '--compress',
    '--times',
    '--recursive',
    '--links',
    '--perms',
    '--inplace',
    '--delete',
    '--exclude=local_test/tmp',
    '--exclude=.git',
  ].flatten.join(' ')
  conf.packaging_dir = `git rev-parse --show-toplevel`.strip
  conf.spec_files = lambda do
    [
      'local_test/success_spec.rb',
      'local_test/fail_spec.rb',
      'local_test/timeout_spec.rb',
    ]
  end
  conf.setup_command = ''
  conf.slave_command = "bundle exec rrrspec-client slave"
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
