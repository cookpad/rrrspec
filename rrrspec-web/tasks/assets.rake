APP_FILE  = File.expand_path('../../lib/rrrspec/web/app.rb', __FILE__)
APP_CLASS = 'RRRSpec::Web::App'
require 'sinatra/assetpack/rake'

desc 'Build assets'
task 'assets:precompile' => 'assetpack:build'
