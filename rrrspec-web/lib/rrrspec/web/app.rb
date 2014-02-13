require 'sinatra/base'
require 'sinatra/assetpack'
require 'haml'
require 'sass'
require 'coffee-script'

module RRRSpec
  module Web
    class App < Sinatra::Base
      configure do
        set :root, File.expand_path(File.join(__FILE__, '..', '..', '..', '..'))
        set :haml, :format => :html5
      end

      register Sinatra::AssetPack

      assets do
        JSLIBS = [
          '/js/vendor/jquery-1.10.2.min.js',
          '/js/vendor/underscore-min.js',
          '/js/vendor/backbone-min.js',
          '/js/vendor/mustache.js',
          '/js/vendor/bootstrap.min.js',
          '/js/vendor/moment.min.js',
          '/js/models.js',
        ]

        CSSLIBS = [
          '/css/vendor/bootstrap.min.css',
          '/css/vendor/bootstrap-theme.min.css',
        ]

        js :tasksets, JSLIBS + ["/js/tasksets.js"]
        js :index, JSLIBS + ["/js/index.js"]
        css :application, CSSLIBS + ["/css/application.css"]

        js_compression :jsmin
        css_compression :simple

        prebuild true
        cache_dynamic_assets true
      end

      get('/') { haml :index }
      get('/tasksets/*') { haml :taskset }
    end
  end
end
