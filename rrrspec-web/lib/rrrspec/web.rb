require 'active_record'
require 'kaminari/grape'

require 'rrrspec'
require 'rrrspec/server'
require 'rrrspec/web/persistent_models'
require 'rrrspec/web/api'
require 'rrrspec/web/app'
require 'rrrspec/web/configuration'

RRRSpec.configuration = RRRSpec::Web::WebConfiguration.new
ActiveSupport::JSON::Encoding.time_precision = 0

module RRRSpec
  module Web
    def self.setup
      ActiveRecord::Base.establish_connection(
        **RRRSpec.configuration.persistence_db
      )
    end
  end
end

