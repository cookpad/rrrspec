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

  spec.add_development_dependency "bundler", "~> 1.4"
  spec.add_development_dependency "rake"
  spec.add_dependency "activesupport"
  spec.add_dependency "tzinfo"
  spec.add_dependency "extreme_timeout"
  spec.add_dependency "faye-websocket"
  spec.add_dependency "rspec", ">= 2.14.1"
  spec.add_dependency "thor"
end
