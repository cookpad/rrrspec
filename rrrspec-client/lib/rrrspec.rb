require 'socket'
require 'logger'
Time.zone_default = Time.find_zone('UTC')

module RRRSpec
  mattr_accessor :application_type
  mattr_accessor :config

  module_function

  def configure(type=nil)
    if type == nil || type == application_type
      yield config
    end
  end


  DEFAULT_CONFIG_FILES = [
    File.expand_path('~/.rrrspec'),
    '.rrrspec',
    '.rrrspec-local'
  ]

  def logger
    @logger ||= Logger.new(STDERR)
  end

  def logger=(logger)
    @logger = logger
  end
end
