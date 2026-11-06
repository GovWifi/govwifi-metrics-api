# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Metrics API' do
  describe 'GET /' do
    it 'returns 200 OK' do
      get '/'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq({ 'status' => 'OK' })
    end
  end

  describe 'GET /health' do
    it 'returns 200 OK when DB is connected' do
      get '/health'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to include('status' => 'OK', 'database' => 'connected')
    end
  end

  describe 'POST /v1/record' do
    let(:valid_payload) do
      {
        name: 'cpu_usage',
        value: '55.5',
        datetime: '2023-10-27T10:00:00Z'
      }
    end

    it 'records a valid metric successfully' do
      post '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(201)
      expect(JSON.parse(last_response.body)).to eq({ 'message' => 'Metric recorded successfully' })
      expect(DB[:metrics].where(name: 'cpu_usage').count).to eq(1)
    end

    it 'returns 422 for missing name' do
      payload = { value: '55.5' }
      post '/v1/record', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(422)
    end

    it 'returns 400 for bad JSON' do
      post '/v1/record', 'invalid json', { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
    end

    context 'with METRICS_API_KEY authentication' do
      before do
        allow(ENV).to receive(:fetch).with('METRICS_API_KEY', nil).and_return('secret_key')
      end

      it 'returns 401 without key' do
        post '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(401)
      end

      it 'returns 201 with correct key' do
        header 'Authorization', 'Bearer secret_key'
        post '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(201)
      end

      it 'returns 401 with wrong key' do
        header 'Authorization', 'Bearer wrong_key'
        post '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(401)
      end

      it 'returns 401 with X-API-KEY (no longer supported)' do
        header 'X-API-KEY', 'secret_key'
        post '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(401)
      end
    end
  end

  describe 'PUT /v1/record' do
    let(:valid_payload) do
      {
        name: 'service-report-peap-unique-users-rolling-count',
        value: '42',
        datetime: '2026-07-17T00:00:00Z'
      }
    end

    it 'updates an existing metric record successfully' do
      DB[:metrics].insert(name: valid_payload[:name], value: 100.0, datetime: Time.parse(valid_payload[:datetime]).utc)
      put '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(DB[:metrics].where(name: valid_payload[:name]).get(:value)).to eq(42.0)
    end

    it 'inserts the metric record if it does not already exist' do
      put '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq({ 'message' => 'Metric updated successfully' })
      expect(DB[:metrics].where(name: valid_payload[:name]).get(:value)).to eq(42.0)
    end

    it 'returns 422 for missing name' do
      payload = { value: '42' }
      put '/v1/record', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(422)
    end

    it 'returns 400 for bad JSON' do
      put '/v1/record', 'invalid json', { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
    end

    it 'returns 500 when an unexpected error occurs' do
      allow(MetricsService).to receive(:update_metric).and_raise(StandardError, 'DB failure')

      put '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(500)
      expect(JSON.parse(last_response.body)).to eq({ 'error' => 'Internal server error' })
    end

    context 'with METRICS_API_KEY authentication' do
      before do
        allow(ENV).to receive(:fetch).with('METRICS_API_KEY', nil).and_return('secret_key')
      end

      it 'returns 401 without key' do
        put '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(401)
      end

      it 'returns 200 with correct key' do
        header 'Authorization', 'Bearer secret_key'
        put '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(200)
      end

      it 'returns 401 with wrong key' do
        header 'Authorization', 'Bearer wrong_key'
        put '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(401)
      end
    end
  end

  describe 'GET /v1/data/export' do
    before do
      DB[:metrics].insert(name: 'm1', value: 1.0, datetime: '2023-01-01T10:00:00Z')
      DB[:metrics].insert(name: 'm2', value: 2.0, datetime: '2023-02-01T10:00:00Z')
      DB[:metrics].insert(name: 'm3', value: 3.0, datetime: '2023-03-01T10:00:00Z')
    end

    it 'returns all metrics when no filters are provided' do
      get '/v1/data/export'
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Disposition']).to match(/.*-metrics-api-data-export.json/)
      expect(JSON.parse(last_response.body).map { |m| m['name'] }).to include('m1', 'm2', 'm3')
    end

    it 'filters by date range' do
      get '/v1/data/export', from: '2023-01-15T00:00:00Z', to: '2023-02-15T00:00:00Z'
      expect(last_response.status).to eq(200)
      results = JSON.parse(last_response.body)
      expect(results.size).to eq(1)
      expect(results.first['name']).to eq('m2')
    end

    it 'filters by year and month' do
      get '/v1/data/export', year: '2023', month: '02'
      expect(last_response.status).to eq(200)
      results = JSON.parse(last_response.body)
      expect(results.size).to eq(1)
      expect(results.first['name']).to eq('m2')
    end

    it 'returns 400 for invalid date format' do
      get '/v1/data/export', from: 'invalid-date'
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)).to include('error' => /Invalid date format/)
    end

    it 'filters by name only' do
      get '/v1/data/export', name: 'm1'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body).map { |m| m['name'] }).to eq(['m1'])
    end

    it 'filters by name when inside target date range' do
      get '/v1/data/export', name: 'm2', from: '2023-01-15T00:00:00Z', to: '2023-02-15T00:00:00Z'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body).map { |m| m['name'] }).to eq(['m2'])
    end

    it 'returns empty when name does not match target date range' do
      get '/v1/data/export', name: 'm1', from: '2023-01-15T00:00:00Z', to: '2023-02-15T00:00:00Z'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq([])
    end

    it 'filters by name when inside target year and month' do
      get '/v1/data/export', name: 'm2', year: '2023', month: '02'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body).map { |m| m['name'] }).to eq(['m2'])
    end

    it 'returns empty when name does not match target year and month' do
      get '/v1/data/export', name: 'm1', year: '2023', month: '02'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq([])
    end

    it 'returns empty array if name does not exist' do
      get '/v1/data/export', name: 'non-existent'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq([])
    end

    it 'ignores name if name is empty or pure whitespace' do
      get '/v1/data/export', name: ' '
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body).size).to eq(3)
    end

    context 'with METRICS_API_KEY authentication' do
      before do
        allow(ENV).to receive(:fetch).with('METRICS_API_KEY', nil).and_return('secret_key')
      end

      it 'returns 401 without key' do
        get '/v1/data/export'
        expect(last_response.status).to eq(401)
      end

      it 'returns 200 with correct key' do
        header 'Authorization', 'Bearer secret_key'
        get '/v1/data/export'
        expect(last_response.status).to eq(200)
      end

      it 'returns 401 with X-API-KEY (no longer supported)' do
        header 'X-API-KEY', 'secret_key'
        get '/v1/data/export'
        expect(last_response.status).to eq(401)
      end
    end
  end
end
