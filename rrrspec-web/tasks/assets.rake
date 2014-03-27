require 'sinatra/asset_pipeline/task'
require 'rrrspec/web'
Sinatra::AssetPipeline::Task.define! RRRSpec::Web::App
