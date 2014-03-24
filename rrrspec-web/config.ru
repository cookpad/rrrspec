require 'rrrspec/web'
require 'shotgun'

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: "db/development.sqlite3")
ActiveRecord::Base.logger = Logger.new($stderr)

RRRSpec.config = RRRSpec::Web::WebConfig.new
RRRSpec.config.execute_log_text_path = 'tmp/log_text'

# require "profile"
# require "logger"
# require "stringio"
#
# class Profile
#   #= initialize
#   def initialize(app)
#     @app = app
#     @logger = Logger.new('log/profile.txt')
#   end
#
#   #= call
#   def call(env)
#     log_profile(env) {
#        @app.call(env)
#     }
#   end
#
#   def log_profile(env)
#     time = Time.now
#
#     Profiler__.start_profile
#     resp = yield
#     Profiler__.stop_profile
#
#     sio = StringIO.new
#     sio.puts "#{env['PATH_INFO']}"
#     Profiler__.print_profile(sio)
#     sio.puts "#{env['PATH_INFO']}"
#
#     @logger.info(sio.string)
#
#     resp
#   end
# end
#
# use Profile
run Rack::Cascade.new([RRRSpec::Web::API.new, RRRSpec::Web::App.new])
