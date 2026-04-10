# frozen_string_literal: true

require 'sequel'

namespace :db do
  desc 'Run migrations'
  task :migrate do
    DB_URL = ENV.fetch('DATABASE_DSN', 'postgres://metrics:metrics_password@db/metrics_db')
    Sequel.extension :migration
    db = Sequel.connect(DB_URL)
    Sequel::Migrator.run(db, 'db/migrations')
    puts 'Migrations complete!'
  end

  desc 'Create db'
  task :create do
    # For Docker convenience, if db does not exist, creating it requires connection to postgres db first.
    # In docker environment postgres is default so we could do:
    require 'pg'
    begin
      conn = PG.connect(host: 'db', user: 'metrics', password: 'metrics_password', dbname: 'postgres')
      conn.exec('CREATE DATABASE metrics_db')
      conn.close
      puts 'Database metrics_db created.'
    rescue ArgumentError, PG::Error => e
      puts "DB might already exist or error: #{e.message}"
    end
  end

  namespace :test do
    desc 'Prepare test db'
    task :prepare do
      ENV['DATABASE_DSN'] = 'postgres://metrics:metrics_password@db/metrics_db'
      Rake::Task['db:migrate'].invoke
    end
  end
end

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new(:rubocop) do |t|
    t.options = ['--display-cop-names']
  end
rescue LoadError
  # rubocop not loaded
end

task default: :test
task test: :rubocop
