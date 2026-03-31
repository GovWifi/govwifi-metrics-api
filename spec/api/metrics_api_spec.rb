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

    context 'with API_KEY authentication' do
      before do
        allow(ENV).to receive(:fetch).with('API_KEY', nil).and_return('secret_key')
      end

      it 'returns 401 without key' do
        post '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(401)
      end

      it 'returns 201 with correct key' do
        header 'X-API-KEY', 'secret_key'
        post '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(201)
      end

      it 'returns 401 with wrong key' do
        header 'X-API-KEY', 'wrong_key'
        post '/v1/record', valid_payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(401)
      end
    end
  end
end
