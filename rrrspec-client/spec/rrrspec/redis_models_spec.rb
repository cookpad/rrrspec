require 'spec_helper'

module RRRSpec
  RSpec.describe Taskset do
    before do
      RRRSpec.configuration = Configuration.new
      RRRSpec.configuration.redis = @redis
    end

    before do
      @worker, @taskset, @task, @worker_log, @slave, @trial =
        RRRSpec.finished_fullset
    end

    describe '#expire' do
      it 'expires all keys' do
        @taskset.expire(60)
        expect(@redis.ttl(@taskset.key)).to be >= 0
        expect(@redis.ttl("#{@taskset.key}:rrrspec:worker:testhostname")).to be >= 0
        expect(@redis.ttl("#{@taskset.key}:rrrspec:worker:testhostname:log")).to be >= 0
        expect(@redis.ttl("#{@taskset.key}:slave")).to be >= 0
        expect(@redis.ttl("#{@taskset.key}:task:spec/test_spec.rb")).to be >= 0
        expect(@redis.ttl("#{@taskset.key}:task:spec/test_spec.rb:trial")).to be >= 0
        expect(@redis.ttl(@task.trials[0].key)).to be >= 0
        expect(@redis.ttl("#{@taskset.key}:task_queue")).to be >= 0
        expect(@redis.ttl("#{@taskset.key}:tasks")).to be >= 0
        expect(@redis.ttl("#{@taskset.key}:worker_log")).to be >= 0
        expect(@redis.ttl(@slave.key)).to be >= 0
        expect(@redis.ttl("#{@slave.key}:log")).to be >= 0
        expect(@redis.ttl("#{@slave.key}:trial")).to be >= 0
      end
    end
  end
end
