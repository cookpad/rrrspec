module RRRSpec
  module Server
    class LargeStringDescriptor
      def initialize(klass, name)
        @klass = klass
        @name = name
      end

      def get(obj)
        proxy
      end

      def set(obj, val)
        proxy.set(val)
      end

      private

      def proxy(obj)
        path_elems = ['rrrspec', @klass.name, @name, obj.id.to_s]
        filepath = File.join(RRRSpec.configuration.execute_log_text_path, path_elems.join('-'))
        LargeStringProxy.new(path_elems.join(':'), filepath)
      end

      class LargeStringProxy
        def initialize(key, filepath)
          @ro = File.exist?(filepath)
          if @ro
            @content = File.read(filepath)
          else
            @key = key
            @filepath = filepath
          end
        end

        def flush
          return if @ro

          FileUtils.mkdir_p(File.dirname(@filepath))
          File.write(@filepath, RRRSpec.redis.get(@key) || "")
          RRRSpec.redis.del(@key)
          @ro = true
        end

        def to_s
          @content || RRRSpec.redis.get(@key) || ""
        end

        def append(string)
          raise "Cannot modify read-only attribute" if @ro
          RRRSpec.redis.append(@key, string)
        end

        def set(string)
          raise "Cannot modify read-only attribute" if @ro
          RRRSpec.redis.set(@key, string)
        end
      end
    end

    def generate_descriptor_method_trait(descriptor_method_name, descriptor_class)
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
