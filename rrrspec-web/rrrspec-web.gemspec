# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rrrspec/web/version'
require 'pathname'

Gem::Specification.new do |spec|
  spec.name          = "rrrspec-web"
  spec.version       = RRRSpec::Web::VERSION
  spec.authors       = ["Masaya Suzuki"]
  spec.email         = ["draftcode@gmail.com"]
  spec.description   = "Execute RSpec in a distributed manner"
  spec.summary       = "Execute RSpec in a distributed manner"
  spec.homepage      = "https://github.com/cookpad/rrrspec"
  spec.license       = "MIT"

  gemspec_dir = File.expand_path('..', __FILE__)
  spec.files  = Dir['assets/**/*', 'lib/**/*.rb', 'tasks/**/*.rake', 'views/**/*', 'compass.config', 'config.ru']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "database_cleaner", "~> 1.2.0"
  spec.add_development_dependency "guard-livereload"
  spec.add_development_dependency "mysql2"
  spec.add_development_dependency "rack-livereload"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "sqlite3"
  spec.add_dependency "activerecord", "~> 4.2.0"
  spec.add_dependency "activesupport"
  spec.add_dependency "api-pagination", "~> 4.8.1"
  spec.add_dependency "bootstrap-sass", ">= 3.2"
  spec.add_dependency "coffee-script", "~> 2.2.0"
  spec.add_dependency "grape", '~> 1.1.0'
  spec.add_dependency "haml", "~> 4.0.3"
  spec.add_dependency "kaminari", "~> 0.16.0"
  spec.add_dependency "oj"
  spec.add_dependency "rrrspec-client"
  spec.add_dependency "rrrspec-server"
  spec.add_dependency "sass"
  spec.add_dependency "sinatra", "~> 1.4.3"
  spec.add_dependency "sinatra-asset-pipeline"
end
