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
