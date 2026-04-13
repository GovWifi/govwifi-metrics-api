# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Host Authorization' do
  context 'when Host header is localhost (default permitted)' do
    it 'allows access to the root path' do
      get '/', {}, { 'HTTP_HOST' => 'localhost' }
      expect(last_response.status).to eq(200)
    end

    it 'allows access to the health path' do
      get '/health', {}, { 'HTTP_HOST' => 'localhost' }
      expect(last_response.status).to eq(200)
    end
  end

  context 'when Host header is unknown' do
    it 'denies access to the root path (returns 403 Forbidden)' do
      get '/', {}, { 'HTTP_HOST' => 'unknown.com' }
      expect(last_response.status).to eq(403)
      expect(last_response.body).to include('Host not permitted')
    end

    it 'allows access to the health path due to the bypass' do
      get '/health', {}, { 'HTTP_HOST' => 'unknown.com' }
      expect(last_response.status).to eq(200)
    end
  end
end
