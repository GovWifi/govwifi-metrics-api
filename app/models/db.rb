# frozen_string_literal: true

require 'sequel'

ENV['DATABASE_URL'] ||= 'postgres://metrics:metrics_password@db/metrics_db'

DB = Sequel.connect(ENV.fetch('DATABASE_URL', nil))
