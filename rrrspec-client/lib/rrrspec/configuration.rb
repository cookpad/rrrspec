module RRRSpec
  class Configuration
    attr_accessor :loaded
    attr_reader :type

    def redis=(arg)
      @redis_value = arg
    end

    def redis
      case @redis_value
      when Hash then Redis.new(@redis_value)
      when Proc then @redis_value.call
      else @redis_value
      end
    end

    def check_validity
      validity = true

      unless @redis_value
        $stderr.puts("Redis configuration is empty")
        validity = false
      end

      validity
    end

    def load_files(files)
      loaded = []
      files.each do |filepath|
        filepath = File.absolute_path(filepath)
        next unless File.exists?(filepath)
        $stderr.puts("Loading: #{filepath}")
        load filepath
        loaded << filepath
      end

      RRRSpec.configuration.loaded = loaded
    end
  end
end
