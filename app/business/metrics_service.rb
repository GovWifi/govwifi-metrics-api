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
      from = params[:from]
      to = params[:to]
      year = params[:year]
      month = params[:month]

      dataset = DB[:metrics]

      if from || to
        start_time = from ? Time.parse(from).utc : nil
        end_time = to ? Time.parse(to).utc : nil

        dataset = dataset.where(Sequel.lit('datetime >= ?', start_time)) if start_time
        dataset = dataset.where(Sequel.lit('datetime <= ?', end_time)) if end_time
      elsif year && month
        start_time = Time.utc(year.to_i, month.to_i, 1)
        end_time = if month.to_i == 12
                     Time.utc(year.to_i + 1, 1, 1)
                   else
                     Time.utc(year.to_i, month.to_i + 1, 1)
                   end
        dataset = dataset.where(datetime: start_time...end_time)
      end

      dataset.order(:datetime).all
    rescue ArgumentError, TypeError => e
      raise ArgumentError, "Invalid date format: #{e.message}"
    end
  end
end
