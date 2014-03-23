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
          '/js/vendor/handlebars-v1.3.0.js',
          File.join(Bootstrap.javascripts_path, 'bootstrap', 'affix'),
          File.join(Bootstrap.javascripts_path, 'bootstrap', 'alert'),
          File.join(Bootstrap.javascripts_path, 'bootstrap', 'button'),
          File.join(Bootstrap.javascripts_path, 'bootstrap', 'carousel'),
          File.join(Bootstrap.javascripts_path, 'bootstrap', 'collapse'),
          File.join(Bootstrap.javascripts_path, 'bootstrap', 'dropdown'),
          File.join(Bootstrap.javascripts_path, 'bootstrap', 'tab'),
          File.join(Bootstrap.javascripts_path, 'bootstrap', 'transition'),
          File.join(Bootstrap.javascripts_path, 'bootstrap', 'scrollspy'),
          File.join(Bootstrap.javascripts_path, 'bootstrap', 'modal'),
          File.join(Bootstrap.javascripts_path, 'bootstrap', 'tooltip'),
          File.join(Bootstrap.javascripts_path, 'bootstrap', 'popover'),
          '/js/vendor/moment.min.js',
          '/js/models.js',
        ]

        CSSLIBS = [
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
