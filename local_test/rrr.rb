#!/usr/bin/env ruby
require 'rrrspec/client/rspec_runner'
require 'rrrspec/client/slave_runner'

rspec_runner = RRRSpec::Client::RSpecRunner.new
ARGV.each do |path|
  rspec_runner.reset
  status, outbuf, errbuf = rspec_runner.setup(path)
  p [status, outbuf, errbuf]
  unless status
    next
  end
  formatter = RRRSpec::Client::SlaveRunner::RedisReportingFormatter
  status, outbuf, errbuf = rspec_runner.run(formatter)
  p [status, outbuf, errbuf]
  if status
    p [formatter.status, formatter.passed, formatter.pending, formatter.failed]
  end
end
