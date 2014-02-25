module RRRSpec
  module Server
    # LogFilePersister
    #
    #     class Taskset < ActiveRecord::Base
    #       include LogFilePersister
    #       save_as_file :log, suffix: 'log'
    #     end
    #
    # Requirements:
    #
    # * Have a property named 'key'
    # * Set RRRSpec.configuration.execute_log_text_path
    #
    # Provides:
    #
    # * Methods named 'log', 'log=', 'log_log_path'.
    # * 'after_save' hook that persists a log to the file pointed by log_log_path.
    # * Persist the value of the 'log' to File.join(execute_log_text_path, "#{key}_log.log") if it is dirty.
    module LogFilePersister
      extend ActiveSupport::Concern

      module ClassMethods
        def save_as_file(name, suffix: nil)
          suffix = "_#{suffix}" if suffix
          instance_variable_set("@#{name}_dirty", false)
          define_method("#{name}_log_path") do
            return nil unless send(:key)
            File.join(
              RRRSpec.configuration.execute_log_text_path,
              "#{send(:key).gsub(/[\/:]/, '_')}#{suffix}.log"
            )
          end

          define_method(name) do
            contents = instance_variable_get("@#{name}")
            if !contents
              log_path = send("#{name}_log_path")
              if log_path
                contents = File.exist?(log_path) ?  File.read(log_path) : nil
                instance_variable_set("@#{name}", contents) if contents
              end
            end
            contents
          end

          define_method("#{name}=") do |val|
            if send(name) != val
              instance_variable_set("@#{name}_dirty", true)
              instance_variable_set("@#{name}", val)
            end
          end

          after_save do
            if instance_variable_get("@#{name}")
              log_path = send("#{name}_log_path")
              FileUtils.mkdir_p(File.dirname(log_path))
              File.open(log_path, 'w') { |fp| fp.write(send(name)) }
            end
          end
        end
      end
    end
  end
end
