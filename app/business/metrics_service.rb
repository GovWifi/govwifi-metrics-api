# frozen_string_literal: true

require 'time'
require_relative 'metrics_contract'
require_relative '../models/db'
require_relative '../models/logger'

class MetricsService
  class << self
    def record_metric(params)
      contract = MetricsContract.new
      result = contract.call(params)

      if result.failure?
        AppLogger.logger.warn('Validation failed', errors: result.errors.to_h, params: params)
        raise ArgumentError, result.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
      end

      data = result.to_h
      name = data[:name]
      value = Float(data[:value])
      datetime = data[:datetime]

      metric_datetime = if datetime.to_s.strip.empty?
                          Time.now.utc
                        else
                          Time.parse(datetime).utc
                        end

      DB[:metrics].insert(
        name: name,
        value: value,
        datetime: metric_datetime
      )
      AppLogger.logger.info('Metric recorded', name: name, value: value, datetime: metric_datetime)
    rescue Sequel::UniqueConstraintViolation
      AppLogger.logger.warn('Duplicate metric record attempt', name: name, datetime: metric_datetime)
      raise ArgumentError, "Metric '#{name}' at '#{metric_datetime}' already exists"
    rescue StandardError => e
      AppLogger.logger.error('Error recording metric', error: e.message, params: params)
      raise
    end

    def export_metrics(params)
      dataset = DB[:metrics]

      if params[:from] || params[:to]
        dataset = apply_date_range_filter(dataset, params[:from], params[:to])
      elsif params[:year] && params[:month]
        dataset = apply_monthly_filter(dataset, params[:year], params[:month])
      end

      dataset.order(:datetime).all
    rescue ArgumentError, TypeError => e
      raise ArgumentError, "Invalid date format: #{e.message}"
    end

    private

    def apply_date_range_filter(dataset, from, to)
      dataset = dataset.where(Sequel.lit('datetime >= ?', Time.parse(from).utc)) if from
      dataset = dataset.where(Sequel.lit('datetime <= ?', Time.parse(to).utc)) if to
      dataset
    end

    def apply_monthly_filter(dataset, year, month)
      year = year.to_i
      month = month.to_i
      start_time = Time.utc(year, month, 1)
      end_time = month == 12 ? Time.utc(year + 1, 1, 1) : Time.utc(year, month + 1, 1)
      dataset.where(datetime: start_time...end_time)
    end
  end
end
