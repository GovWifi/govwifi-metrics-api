# frozen_string_literal: true

require 'dry-validation'

class MetricsContract < Dry::Validation::Contract
  params do
    required(:name).filled(:string)
    required(:value).filled { float? | int? | decimal? | (str? & format?(/\A-?\d+(\.\d+)?\z/)) }
    optional(:datetime).maybe(:string)
  end
end
