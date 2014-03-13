module RRRSpec
  module Server
    class LargeStringDescriptor
      def initialize(klass, name)
        @klass = klass
        @name = name
      end

      def get(obj)
        proxy(obj)
      end

      def set(obj, val)
        proxy(obj).set(val)
      end

      private

      def proxy(obj)
        path_elems = ['rrrspec', @klass.name, @name, obj.id.to_s]
        filepath = File.join(RRRSpec.config.execute_log_text_path, path_elems.join('-'))
        LargeStringProxy.new(path_elems.join(':'), filepath)
      end

      class LargeStringProxy
        def initialize(key, filepath)
          @key = key
          @filepath = filepath
        end

        def flush
          return if File.exist?(@filepath)

          FileUtils.mkdir_p(File.dirname(@filepath))
          File.write(@filepath, RRRSpec::Server.redis.get(@key) || "")
          RRRSpec::Server.redis.del(@key)
        end

        def to_s
          if File.exist?(@filepath)
            File.read(@filepath)
          else
            RRRSpec::Server.redis.get(@key) || ''
          end
        end

        def append(string)
          if File.exist?(@filepath)
            File.write(@filepath, string, mode: 'a')
          else
            RRRSpec::Server.redis.append(@key, string)
          end
        end

        def set(string)
          if File.exist?(@filepath)
            File.write(@filepath, string)
          else
            RRRSpec::Server.redis.set(@key, string)
          end
        end
      end
    end

    def self.generate_descriptor_method_trait(descriptor_method_name, descriptor_class)
      Module.new do
        define_singleton_method(:included) do |klass|
          klass.send(:extend, Module.new do
            define_method(descriptor_method_name) do |attr_name, *args|
              descriptor = descriptor_class.new(self, attr_name, *args)

              define_method(attr_name) { descriptor.get(self) }
              define_method("#{attr_name}=") { |val| descriptor.set(self, val) }
            end
          end)
        end
      end
    end

    LargeStringAttribute = generate_descriptor_method_trait(:large_string, LargeStringDescriptor)
  end
end
