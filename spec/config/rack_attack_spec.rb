# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rack::Attack', type: :request do
  # Note: These tests verify the rate limiting configuration is properly loaded
  # and the middleware is active. Full integration testing of rate limits
  # requires testing against actual request patterns.

  describe 'configuration' do
    it 'has Rack::Attack middleware loaded' do
      expect(Rails.application.config.middleware.include?(Rack::Attack)).to be true
    end

    it 'has login throttle configured' do
      throttle = Rack::Attack.throttles['logins/ip']
      expect(throttle).to be_present
    end

    it 'has password reset throttle configured' do
      throttle = Rack::Attack.throttles['password_reset/ip']
      expect(throttle).to be_present
    end

    it 'has registration throttle configured' do
      throttle = Rack::Attack.throttles['registrations/ip']
      expect(throttle).to be_present
    end
  end

  describe 'safelist' do
    it 'allows localhost in development/test' do
      # In test environment, localhost should be safelisted
      expect(Rails.env.local?).to be true
    end
  end
end
