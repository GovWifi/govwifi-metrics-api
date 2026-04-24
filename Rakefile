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

  desc 'Seed mock metrics data'
  task :seed_metrics do
    require 'time'
    DB_URL = ENV.fetch('DATABASE_DSN', 'postgres://metrics:metrics_password@db/metrics_db')
    db = Sequel.connect(DB_URL)

    years = (ENV['YEARS'] || 2).to_i
    puts "Generating #{years} years of metrics data..."

    metrics = %w[authentications registrations active_users]
    end_date = Time.now.utc
    start_date = end_date - (years * 365 * 24 * 60 * 60)

    current_date = start_date
    count = 0

    db.transaction do
      while current_date <= end_date
        metrics.each do |name|
          value = case name
                  when 'authentications' then rand(1000..5000)
                  when 'registrations' then rand(50..200)
                  when 'active_users' then rand(5000..10_000)
                  else rand(1..100)
                  end

          begin
            db[:metrics].insert(
              name: name,
              value: value,
              datetime: current_date
            )
            count += 1
          rescue Sequel::UniqueConstraintViolation
            # Skip duplicates
          end
        end
        current_date += (24 * 60 * 60) # Increment by one day
      end
    end

    puts "Done! Generated #{count} records from #{start_date.to_date} to #{end_date.to_date}."
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
