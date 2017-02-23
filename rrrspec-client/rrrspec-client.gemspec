# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rrrspec/client/version'
require 'pathname'

Gem::Specification.new do |spec|
  spec.name          = "rrrspec-client"
  spec.version       = RRRSpec::Client::VERSION
  spec.authors       = ["Masaya Suzuki"]
  spec.email         = ["draftcode@gmail.com"]
  spec.description   = "Execute RSpec in a distributed manner"
  spec.summary       = "Execute RSpec in a distributed manner"
  spec.homepage      = "https://github.com/cookpad/rrrspec"
  spec.license       = "MIT"

  gemspec_dir = File.expand_path('..', __FILE__)
  spec.files  = Dir['bin/*', 'lib/**/*.rb']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_dependency "activesupport"
  spec.add_dependency "extreme_timeout", ">=0.3.2"
  spec.add_dependency "launchy"
  spec.add_dependency "redis"
  spec.add_dependency "rspec", ">= 3.0", "< 3.5.0"
  spec.add_dependency "thor", ">= 0.18.0"
  spec.add_dependency "uuidtools"
  spec.add_dependency "tzinfo"
end
