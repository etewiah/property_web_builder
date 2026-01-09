# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Zoho::Client do
  let(:test_credentials) do
    {
      client_id: 'test_client_id',
      client_secret: 'test_client_secret',
      refresh_token: 'test_refresh_token',
      api_domain: 'https://www.zohoapis.com',
      accounts_url: 'https://accounts.zoho.com'
    }
  end

  before do
    # Reset singleton between tests
    described_class.reset!
  end

  describe '.instance' do
    before do
      allow(Rails.application.credentials).to receive(:zoho).and_return(test_credentials)
    end

    it 'returns a singleton instance' do
      instance1 = described_class.instance
      instance2 = described_class.instance
      expect(instance1).to be(instance2)
    end

    it 'can be reset' do
      instance1 = described_class.instance
      described_class.reset!
      instance2 = described_class.instance
      expect(instance1).not_to be(instance2)
    end
  end

  describe '#configured?' do
    context 'when all credentials are present' do
      before do
        allow(Rails.application.credentials).to receive(:zoho).and_return(test_credentials)
      end

      it 'returns true' do
        client = described_class.new
        expect(client.configured?).to be true
      end
    end

    context 'when credentials are missing' do
      before do
        allow(Rails.application.credentials).to receive(:zoho).and_return({})
      end

      it 'returns false' do
        client = described_class.new
        expect(client.configured?).to be false
      end
    end

    context 'when only some credentials are present' do
      before do
        allow(Rails.application.credentials).to receive(:zoho).and_return({
                                                                            client_id: 'test_id',
                                                                            client_secret: nil,
                                                                            refresh_token: nil
                                                                          })
      end

      it 'returns false' do
        client = described_class.new
        expect(client.configured?).to be false
      end
    end
  end

  describe 'ConfigurationError' do
    before do
      allow(Rails.application.credentials).to receive(:zoho).and_return({})
    end

    it 'raises ConfigurationError when not configured and making API calls' do
      client = described_class.new
      expect { client.get('/Leads') }.to raise_error(Pwb::Zoho::ConfigurationError)
    end
  end

  describe 'error classes' do
    it 'defines Error as base class' do
      expect(Pwb::Zoho::Error).to be < StandardError
    end

    it 'defines ConfigurationError' do
      expect(Pwb::Zoho::ConfigurationError).to be < Pwb::Zoho::Error
    end

    it 'defines AuthenticationError' do
      expect(Pwb::Zoho::AuthenticationError).to be < Pwb::Zoho::Error
    end

    it 'defines ValidationError' do
      expect(Pwb::Zoho::ValidationError).to be < Pwb::Zoho::Error
    end

    it 'defines NotFoundError' do
      expect(Pwb::Zoho::NotFoundError).to be < Pwb::Zoho::Error
    end

    it 'defines ApiError' do
      expect(Pwb::Zoho::ApiError).to be < Pwb::Zoho::Error
    end

    it 'defines TimeoutError' do
      expect(Pwb::Zoho::TimeoutError).to be < Pwb::Zoho::Error
    end

    it 'defines ConnectionError' do
      expect(Pwb::Zoho::ConnectionError).to be < Pwb::Zoho::Error
    end

    it 'defines RateLimitError with retry_after' do
      error = Pwb::Zoho::RateLimitError.new('Rate limited', retry_after: 120)
      expect(error.retry_after).to eq(120)
    end
  end
end
