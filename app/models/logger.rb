# frozen_string_literal: true

require 'ougai'

module AppLogger
  def self.logger
    @logger ||= begin
      logger = Ougai::Logger.new($stdout)
      logger.level = case ENV.fetch('LOG_LEVEL', 'info').downcase
                     when 'debug' then Logger::DEBUG
                     when 'warn' then Logger::WARN
                     when 'error' then Logger::ERROR
                     else Logger::INFO
                     end
      logger
    end
  end
end
