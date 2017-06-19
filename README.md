# RRRSpec

RRRSpec enables you to run RSpec in a distributed manner.

This is developed for the purpose to obtain the fault-tolerance properties to
process-failures, machine-failures, and unresponsiveness of processes in the
automated testing process.

RRRSpec is used in production as a CI service, running 60+ RSpec processes
concurrently, and it undergoes those failures, which include lots of `rb_bug`s,
assertion errors, and segmentation faults.

## Features

* Automatic resume on process or machine failures
* RSpec integration
* Captured stdout/stderr per tests
* Automatic retrial of failed tests
* Optimization of the test execution order
* Speculative execution of long-running tests
* Severe timeout of stuck processes

Some considerations on creating RRRSpec are described in DESIGN.md, hoping it
helps other developers writing other distributed test execution services avoid
common pitfalls.

## Installation

### Client

Add this line to your application's Gemfile:

    gem 'rrrspec-client'

Create '.rrrspec'

    RRRSpec.configure(:client) do |conf|
      Time.zone_default = Time.find_zone('Asia/Tokyo')
      conf.redis = { host: 'redisserver.local', port: 6379 }

      conf.packaging_dir = `git rev-parse --show-toplevel`.strip
      conf.rsync_remote_path = 'rsyncserver.local:/mnt/rrrspec-rsync'
      conf.rsync_options = %w(
        --compress
        --times
        --recursive
        --links
        --perms
        --inplace
        --delete
      ).join(' ')

      conf.spec_files = lambda do
        Dir.chdir(conf.packaging_dir) do
          Dir['spec/**{,/*/**}/*_spec.rb'].uniq
        end
      end

      conf.setup_command = <<-SETUP
        bundle install
      SETUP
      conf.slave_command = <<-SLAVE
        bundle exec rrrspec-client slave
      SLAVE

      conf.taskset_class = 'myapplication'
      conf.worker_type = 'default'
      conf.max_workers = 10
      conf.max_trials = 3
      conf.unknown_spec_timeout_sec = 8 * 60
      conf.least_timeout_sec = 60
    end

### Master and Workers

Install 'rrrspec-server'

    $ gem install rrrspec-server

Create 'rrrspec-server-config.rb'

    RRRSpec.configure do |conf|
      conf.redis = { host: 'redisserver.local', port: 6379 }
    end

    RRRSpec.configure(:server) do |conf|
      ActiveRecord::Base.default_timezone = :local
      conf.redis = { host: 'redisserver.local', port: 6379 }

      conf.persistence_db = {
        adapter: 'mysql2',
        encoding: 'utf8mb4',
        charset: 'utf8mb4',
        collation: 'utf8mb4_general_ci',
        reconnect: false,
        database: 'rrrspec',
        pool: 5,
        host: 'localhost'
      }
      conf.execute_log_text_path = '/tmp/rrrspec-log-texts'
    end

    RRRSpec.configure(:worker) do |conf|
      conf.redis = { host: 'redisserver.local', port: 6379 }

      conf.rsync_remote_path = 'rsyncserver.local:/mnt/rrrspec-rsync'
      conf.rsync_options = %w(
        --compress
        --times
        --recursive
        --links
        --perms
        --inplace
        --delete
      ).join(' ')

      conf.working_dir = '/mnt/working'
      conf.worker_type = 'default'
    end

## Usage

### Master and Workers

    $ rrrspec-server server --config=rrrspec-server-config.rb

    $ rrrspec-server worker --config=rrrspec-server-config.rb

### Client

    $ bundle exec rrrspec-client start

## Local test
You can try RRRSpec locally using Docker.

```
% docker-compose up
% docker-compose run worker local_test/run_client.sh
% xdg-open http://localhost:3000/
```

## Contributing

See HACKING.md for the internal structure.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
