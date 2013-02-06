namespace :db do
  require 'active_record'
  require 'logger'

  task :establish_connection do
    require 'yaml'
    dbconfig = YAML::load(File.open('config/db.yml'))
    ActiveRecord::Base.establish_connection(dbconfig)
  end

  desc "Migrate the database"
  task :migrate => :establish_connection do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.migrate('db/migrate')
  end

  desc 'Rolls the schema back to the previous version (specify steps w/ STEP=n).'
  task :rollback => :establish_connection do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    ActiveRecord::Migrator.rollback('db/migrate', step)
  end

  desc 'Rolls back all migrations and reruns them'
  task :reset => :establish_connection do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.down('db/migrate')
    ActiveRecord::Migrator.migrate('db/migrate')
  end
end

namespace :gd do
  task :update => 'db:establish_connection' do
    start_date = Date.new(2012,4,1)
    end_date = Date.new(2012,4,15)
    league = 'aaa'

    require './GamedayFetcher'
    gdf = GamedayFetcher.new
    gdf.get_days(league, start_date, end_date)

    require './GamedayParser'
    gdp = GamedayParser.new
    gdp.parse_day(league,year,month,day)
  end
end
