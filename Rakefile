namespace :db do
	require 'active_record'

  task :environment do
  	require 'yaml'
  	dbconfig = YAML::load(File.open('config/db.yml'))
    ActiveRecord::Base.establish_connection(dbconfig)
  end

  desc "Migrate the database"
  task(:migrate => :environment) do
    require 'logger'
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.migrate("db/migrate")
  end
end
