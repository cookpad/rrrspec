# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper"` to ensure that it is only
# loaded once.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
require 'rrrspec/client'
require 'fixture'

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
  config.disable_monkey_patching!
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  pid = nil
  config.before(:suite) do
    pid = Kernel.spawn("redis-server --port 9999 --save ''",
                       in: '/dev/null', out: '/dev/null', err: '/dev/null')
    redis = Redis.new(port: 9999)
    retry_count = 1
    loop do
      begin
        redis.ping
        break
      rescue Redis::CannotConnectError
        if retry_count < 10
          retry_count += 1
          sleep 0.01
          retry
        end
        raise
      end
    end
  end

  config.before(:each) do
    @redis = Redis.new(port: 9999)
    @redis.flushall

    RRRSpec.configuration = nil
    RRRSpec.flushredis
    RRRSpec.hostname = 'testhostname'
  end

  config.after(:suite) do
    Process.kill('KILL', pid) if pid
  end
end
