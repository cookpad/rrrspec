require 'redis'
# XXX: With activesupport 4.1, we cannot require active_support/core_ext due to
# "uninitialized constant ActiveSupport::Autoload (NameError)".
require 'active_support/dependencies/autoload'
require 'active_support/deprecation'
require 'active_support/core_ext'
require 'active_support/time'
require 'socket'
require 'logger'
Time.zone_default = Time.find_zone('UTC')

require 'rrrspec/configuration'
require 'rrrspec/extension'
require 'rrrspec/redis_models'

module RRRSpec
  module_function

  def configuration
    @configuration
  end

  def configuration=(configuration)
    @configuration = configuration
  end

  def configure(type=nil)
    if type == nil || type == configuration.type
      yield configuration
    end
  end

  def redis
    # After the process is daemonized, the redis instance is in invalid state.
    # We avoid using such instance by checking the PID.
    if not Thread.current[:pid] or Thread.current[:pid] != Process.pid
      Thread.current[:redis] = nil
      Thread.current[:pid] = Process.pid
    end

    # It is probable that if two other threads shares one redis connection
    # one thread blocks the other thread. We avoid this by using separate
    # connections.
    Thread.current[:redis] ||= begin
                                 configuration.redis.dup
                               end
  end

  def flushredis
    Thread.list.each do |thread|
      thread[:redis] = nil
      thread[:pid] = nil
    end
  end

  def make_key(*args)
    args.join(':')
  end

  def hostname
    @hostname ||= Socket.gethostname
  end

  def hostname=(hostname)
    @hostname = hostname
  end

  def pacemaker(obj, time, margin)
    loop do
      obj.heartbeat(time)
      sleep time - margin
    end
  end

  # When there's no suitable home directory, File.expand_path raises ArgumentError
  home_rrrspec = File.expand_path('~/.rrrspec') rescue nil
  DEFAULT_CONFIG_FILES = [
    home_rrrspec,
    '.rrrspec',
    '.rrrspec-local'
  ].compact

  def setup(configuration, config_files)
    RRRSpec.configuration = configuration
    files = config_files
    files += ENV['RRRSPEC_CONFIG_FILES'].split(':') if ENV['RRRSPEC_CONFIG_FILES']
    files += DEFAULT_CONFIG_FILES if files.empty?
    RRRSpec.configuration.load_files(files)
    exit 1 unless RRRSpec.configuration.check_validity
  end

  def logger
    @logger ||= Logger.new(STDERR)
  end

  def logger=(logger)
    @logger = logger
  end

  class TimedLogger
    def initialize(obj)
      @obj = obj
    end

    def write(string)
      now = Time.zone.now
      @obj.append_log(now.strftime("%F %T ") + string + "\n")
    end
  end
end
