# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require_relative '../business/metrics_service'

class MetricsApi < Sinatra::Base
  configure do
    set :show_exceptions, false
  end

  before do
    content_type :json
    if request.request_method == 'POST'
      api_key = ENV.fetch('API_KEY', nil)
      halt 401, { error: 'Unauthorized' }.to_json if api_key && request.env['HTTP_X_API_KEY'] != api_key
    end
  end

  get '/' do
    status 200
    { status: 'OK' }.to_json
  end

  get '/health' do
    DB.test_connection
    status 200
    { status: 'OK', database: 'connected' }.to_json
  rescue StandardError => e
    status 503
    { status: 'Error', database: 'disconnected', error: e.message }.to_json
  end

  post '/v1/record' do
    data = JSON.parse(request.body.read)

    MetricsService.record_metric(data)

    status 201
    { message: 'Metric recorded successfully' }.to_json
  rescue JSON::ParserError
    status 400
    { error: 'Invalid JSON request body' }.to_json
  rescue ArgumentError => e
    status 422
    { error: e.message }.to_json
  rescue StandardError
    status 500
    { error: 'Internal server error' }.to_json
  end
end
