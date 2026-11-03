# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MetricsService do
  describe '.record_metric' do
    it 'creates a metric' do
      expect do
        described_class.record_metric({ 'name' => 'memory_usage', 'value' => 1024.5,
                                        'datetime' => '2023-10-27T10:00:00Z' })
      end.to change { DB[:metrics].count }.by(1)
    end

    it 'defaults datetime to now if missing' do
      now = Time.now.utc
      allow(Time).to receive(:now).and_return(now)

      described_class.record_metric({ 'name' => 'memory_usage', 'value' => 1024.5 })

      metric = DB[:metrics].order(:id).last
      expect(metric[:datetime]).to be_within(1).of(now)
    end

    it 'raises error for invalid value' do
      expect do
        described_class.record_metric({ 'name' => 'memory_usage', 'value' => 'not a number' })
      end.to raise_error(ArgumentError, /value is in invalid format|value must be a float/)
    end
  end

  describe '.update_metric' do
    let(:payload) { { 'name' => 'peap_users', 'value' => 65.0, 'datetime' => '2026-07-17T00:00:00Z' } }

    it 'updates an existing metric with the same name and datetime' do
      described_class.record_metric(payload.merge('value' => 100.0))
      expect { described_class.update_metric(payload) }.not_to(change { DB[:metrics].count })
      expect(DB[:metrics].where(name: 'peap_users').get(:value)).to eq(65.0)
    end

    it 'inserts a new metric when no matching record exists' do
      expect { described_class.update_metric(payload) }.to change { DB[:metrics].count }.by(1)
      expect(DB[:metrics].where(name: 'peap_users').get(:value)).to eq(65.0)
    end

    it 'defaults datetime to now if missing' do
      now = Time.now.utc
      allow(Time).to receive(:now).and_return(now)

      described_class.update_metric({ 'name' => 'peap_users', 'value' => 42.0 })

      metric = DB[:metrics].order(:id).last
      expect(metric[:datetime]).to be_within(1).of(now)
    end

    it 'raises ArgumentError for invalid value' do
      expect do
        described_class.update_metric({ 'name' => 'peap_users', 'value' => 'not a number' })
      end.to raise_error(ArgumentError, /value is in invalid format|value must be a float/)
    end
  end
end
