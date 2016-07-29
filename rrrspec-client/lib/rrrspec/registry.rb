require 'rrrspec/client/rspec_runner'
require 'rrrspec/client/rspec_runner_factory'

module RRRSpec
  module Registry

    class NoFactoryForFileExtensionException < Exception

      def initialize(file_extension)
        super "There is no factory for #{file_extension}"
      end
    end

    @@runner_factories = Hash.new

    def self.reset_runner_factories
      @@runner_factories = []
    end

    def self.register_runner_factory(runner_factory, file_extension)
      @@runner_factories[file_extension] = runner_factory
    end


    def self.get_runner_factory(file_extension)
      raise NoFactoryForFileExtensionException, file_extension unless @@runner_factories[file_extension]

      @@runner_factories[file_extension].new
    end

  end

  Registry.register_runner_factory RRRSpec::Client::RSpecRunnerFactory, '.rb'
end
