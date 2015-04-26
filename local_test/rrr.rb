#!/usr/bin/env ruby
require 'rrrspec/client/rspec_runner'
require 'rrrspec/client/slave_runner'

rspec_runner = RRRSpec::Client::RSpecRunner.new
rspec_runner.reset
ARGV.each do |path|
  status, outbuf, errbuf = rspec_runner.setup(path)
  p [status, outbuf, errbuf]
  unless status
    next
  end
  formatter = RRRSpec::Client::SlaveRunner::RedisReportingFormatter.new
  status, outbuf, errbuf = rspec_runner.run(formatter)
  p [status, outbuf, errbuf]
  if status
    p [formatter.status, formatter.passed, formatter.pending, formatter.failed]
  end
end
