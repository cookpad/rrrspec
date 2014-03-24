require 'sinatra/base'
require 'sass'
require 'sinatra/asset_pipeline'
require 'bootstrap-sass'

require 'active_record'
require 'api-pagination'
require 'coffee-script'
require 'grape'
require 'haml'
require 'kaminari/grape'
require 'rack'
require 'oj'

require 'rrrspec'
require 'rrrspec/server'
require 'rrrspec/web/api'
require 'rrrspec/web/app'
require 'rrrspec/web/configuration'

module RRRSpec
  module Web
    def self.application
      RRRSpec.application_type = :web
      RRRSpec.config = WebConfig.new
      load('config/configuration.rb') if File.exists?('config/configuration.rb')

      if File.exists?('config/database.yml')
        require "yaml"
        require "erb"
        env = ENV["RACK_ENV"] ? ENV["RACK_ENV"] : "development"
        ActiveRecord::Base.establish_connection(
          YAML.load(ERB.new(IO.read('config/database.yml')).result)[env]
        )
      end

      Rack::Cascade.new [RRRSpec::Web::API, RRRSpec::Web::App]
    end
  end
end
