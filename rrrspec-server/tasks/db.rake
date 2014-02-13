require "active_support/core_ext/string"
require "active_record"
require "rrrspec/server"

RRRSpec::Server::MIGRATIONS_DIR = File.expand_path('../../db/migrate', __FILE__)

namespace :rrrspec do
  namespace :server do
    task :server_config do
      RRRSpec.setup(RRRSpec::Server::ServerConfiguration.new, [])
      ActiveRecord::Base.establish_connection(**RRRSpec.configuration.persistence_db)
      ActiveRecord::Migrator.migrations_paths = [RRRSpec::Server::MIGRATIONS_DIR]
    end

    namespace :db do
      task :create => 'rrrspec:server:server_config' do
        config = RRRSpec.configuration.persistence_db

        if config[:adapter] =~ /sqlite/
          if File.exist?(config[:database])
            $stderr.puts "#{config[:database]} already exists"
          else
            ActiveRecord::Base.connection
          end
        elsif config[:adapter] =~ /mysql/
          ActiveRecord::Base.connection.create_database(config[:database])
        else
          fail 'unknown database adapter'
        end
      end

      desc "migrate the database"
      task :migrate => 'rrrspec:server:server_config' do
        ActiveRecord::Migrator.migrate(ActiveRecord::Migrator.migrations_paths)
        Rake::Task["rrrspec:server:db:schema:dump"].invoke
      end

      desc "create a migration file"
      task :create_migration, "name" do |t, args|
        version = Time.now.utc.strftime("%Y%m%d%H%M%S")
        filepath = File.join(RRRSpec::Server::MIGRATIONS_DIR, "#{version}_#{args.name}.rb")

        open(filepath, "w") do |f|
          f.write(<<-EOF.strip_heredoc)
          class #{args.name.camelize} < ActiveRecord::Migration
            def change
            end
          end
          EOF
        end
      end

      namespace :schema do
        task :dump => 'rrrspec:server:server_config' do
          File.open(File.expand_path('../../db/schema.rb', __FILE__), "w:utf-8") do |file|
            ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
          end
        end
      end
    end
  end
end
