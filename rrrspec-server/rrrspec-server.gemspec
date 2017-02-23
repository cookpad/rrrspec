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
  spec.homepage      = "https://github.com/cookpad/rrrspec"
  spec.license       = "MIT"

  gemspec_dir = File.expand_path('..', __FILE__)
  spec.files  = Dir['bin/*', 'db/**/*.rb', 'lib/**/*.rb', 'tasks/**/*.rake']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "database_cleaner", "~> 1.2.0"
  spec.add_development_dependency "mysql2"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "< 3.5.0"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "timecop"
  spec.add_dependency "activerecord", ">= 4.2.0", "< 5.1"
  spec.add_dependency "activerecord-import", ">= 0.7.0"
  spec.add_dependency "activesupport"
  spec.add_dependency "bundler"
  spec.add_dependency "facter"
  spec.add_dependency "redis"
  spec.add_dependency "rrrspec-client"
  spec.add_dependency "thor", ">= 0.18.0"
end
