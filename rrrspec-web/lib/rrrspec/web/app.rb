require 'sinatra/base'
require 'sinatra/asset_pipeline'
require 'haml'
require 'sass'
require 'coffee-script'

module RRRSpec
  module Web
    class App < Sinatra::Base
      set :assets_precompile, %w(application.css tasksets.js index.js)
      set :assets_prefix, [
        "#{Gem::Specification.find_by_name('bootstrap-sass').gem_dir}/assets",
        File.expand_path('../../../../assets', __FILE__),
      ]

      register Sinatra::AssetPipeline

      configure do
        set :root, File.expand_path(File.join(__FILE__, '..', '..', '..', '..'))
        set :haml, :format => :html5
      end

      get('/') { haml :index }
      get('/tasksets/*') { haml :taskset }
    end
  end
end
