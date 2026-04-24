# frozen_string_literal: true

require 'rake'
require 'spec_helper'

RSpec.describe 'auth:generate_token' do
  before do
    load 'Rakefile'
    Rake::Task.define_task(:environment)
  end

  it 'generates a 64-character hex string' do
    expect { Rake::Task['auth:generate_token'].invoke }.to output(/Generated API Key: [a-f0-9]{64}/).to_stdout
  end
end
