# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rrrspec/server/version'
require 'pathname'

Gem::Specification.new do |spec|
  spec.name          = "rrrspec-server"
  spec.version       = RRRSpec::Server::VERSION
  spec.authors       = ["Masaya Suzuki"]
  spec.email         = ["draftcode@gmail.com"]
  spec.description   = "Execute RSpec in a distributed manner"
  spec.summary       = "Execute RSpec in a distributed manner"
  spec.homepage      = ""
  spec.license       = "MIT"

  gemspec_dir = File.expand_path('..', __FILE__)
  spec.files  = `git ls-files`.split($/).
    map { |f| File.absolute_path(f) }.
    select { |f| f.start_with?(gemspec_dir) }.
    map { |f| Pathname(f).relative_path_from(Pathname(gemspec_dir)).to_s }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "database_cleaner", "~> 1.2.0"
  spec.add_development_dependency "multi_json"
  spec.add_development_dependency "mysql2"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "timecop"
  spec.add_dependency "activemodel"
  spec.add_dependency "activerecord", "~> 4.0.2"
  spec.add_dependency "activesupport"
  spec.add_dependency "bundler"
  spec.add_dependency "em-hiredis"
  spec.add_dependency "eventmachine"
  spec.add_dependency "faye-websocket"
  spec.add_dependency "hiredis"
  spec.add_dependency "rack"
  spec.add_dependency "redis"
  spec.add_dependency "rrrspec-client"

  spec.add_dependency "thin"

  spec.add_dependency "tzinfo"
end
