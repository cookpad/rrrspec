# coding: utf-8
version = "0.4.2"

Gem::Specification.new do |spec|
  spec.name          = "rrrspec"
  spec.version       = version
  spec.authors       = ["Masaya Suzuki"]
  spec.email         = ["draftcode@gmail.com"]
  spec.description   = "Execute RSpec in a distributed manner"
  spec.summary       = "Execute RSpec in a distributed manner"
  spec.homepage      = "https://github.com/cookpad/rrrspec"
  spec.license       = "MIT"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"

  %w[client server web].each do |name|
    spec.add_dependency "rrrspec-#{name}", version
  end
end
