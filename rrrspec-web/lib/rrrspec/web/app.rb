module RRRSpec
  module Web
    class App < Sinatra::Base
      set :assets_precompile, %w(application.css tasksets.js index.js)
      set :assets_css_compressor, :simple
      set :assets_js_compressor, :jsmin

      register Sinatra::AssetPipeline

      configure do
        set :root, File.expand_path(File.join(__FILE__, '..', '..', '..', '..'))
        set :haml, :format => :html5
        sprockets.append_path("#{Gem::Specification.find_by_name('bootstrap-sass').gem_dir}/vendor/assets/javascripts")
        sprockets.append_path("#{Gem::Specification.find_by_name('bootstrap-sass').gem_dir}/vendor/assets/stylesheets")
      end

      get('/') { haml :index }
      get('/tasksets/*') { haml :taskset }
    end
  end
end
