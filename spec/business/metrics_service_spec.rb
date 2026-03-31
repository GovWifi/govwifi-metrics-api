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
end
