# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Zeitwerk eager loading' do
  # This test ensures all constants can be eager loaded without errors.
  # It catches file naming issues that only appear in production/staging
  # where eager_load is enabled.
  #
  # Common issues caught:
  # - File named `errors.rb` but defines `Error` class (should be `error.rb`)
  # - File named `user.rb` but defines `Users` module (should be `users.rb`)
  # - Missing module definitions
  # - Circular dependencies
  #
  it 'eager loads all constants without errors' do
    expect { Rails.application.eager_load! }.not_to raise_error
  end

  # Verify Zeitwerk is actually configured
  it 'uses Zeitwerk for autoloading' do
    expect(Rails.autoloaders.zeitwerk_enabled?).to be true
  end
end
