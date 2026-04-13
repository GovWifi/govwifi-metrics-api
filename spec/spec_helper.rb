# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

ENV['RACK_ENV'] = 'test'
ENV['DATABASE_DSN'] ||= 'postgres://metrics:metrics_password@db/metrics_db'
ENV['PERMITTED_HOSTS'] ||= 'localhost,example.org'

require 'rspec'
require 'rack/test'
require_relative '../app/api/metrics_api'
require_relative '../app/business/metrics_service'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  config.around do |example|
    DB.transaction(rollback: :always, auto_savepoint: true) do
      example.run
    end
  end
end

def app
  MetricsApi
end
