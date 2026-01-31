# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::Providers::OpenRouter do
  let(:website) { create(:pwb_website) }
  let(:integration) { create(:pwb_website_integration, :open_router, website: website) }

  describe 'class attributes' do
    it 'has category :ai' do
      expect(described_class.category).to eq(:ai)
    end

    it 'has display_name OpenRouter' do
      expect(described_class.display_name).to eq('OpenRouter')
    end

    it 'has a description' do
      expect(described_class.description).to be_present
    end
  end

  describe 'credential fields' do
    it 'requires api_key' do
      expect(described_class.credential_fields[:api_key][:required]).to be true
    end

    it 'has help text for api_key' do
      expect(described_class.credential_fields[:api_key][:help]).to include('openrouter.ai')
    end
  end

  describe 'setting fields' do
    describe 'default_model' do
      let(:field) { described_class.setting_fields[:default_model] }

      it 'is a select field' do
        expect(field[:type]).to eq(:select)
      end

      it 'has options in provider/model format' do
        options = field[:options]
        options.each do |label, value|
          expect(value).to match(%r{^[a-z-]+/[a-z0-9.-]+$}i),
            "Expected '#{value}' to be in provider/model format"
        end
      end

      it 'includes Claude models' do
        model_values = field[:options].map(&:last)
        expect(model_values.any? { |m| m.include?('claude') }).to be true
      end

      it 'includes GPT models' do
        model_values = field[:options].map(&:last)
        expect(model_values.any? { |m| m.include?('gpt') }).to be true
      end

      it 'has a default value' do
        expect(described_class.default_for(:default_model)).to be_present
      end
    end

    describe 'max_tokens' do
      let(:field) { described_class.setting_fields[:max_tokens] }

      it 'is a number field' do
        expect(field[:type]).to eq(:number)
      end

      it 'defaults to 4096' do
        expect(described_class.default_for(:max_tokens)).to eq(4096)
      end
    end
  end

  describe '#validate_connection' do
    let(:provider_instance) do
      described_class.new(integration)
    end

    context 'with valid credentials' do
      before do
        # Mock successful API call
        stub_request(:get, 'https://openrouter.ai/api/v1/models')
          .with(headers: { 'Authorization' => 'Bearer sk-or-test-key-12345' })
          .to_return(status: 200, body: '{"data": []}')
      end

      it 'returns true' do
        expect(provider_instance.validate_connection).to be true
      end
    end

    context 'with invalid API key' do
      before do
        stub_request(:get, 'https://openrouter.ai/api/v1/models')
          .to_return(status: 401, body: '{"error": "Invalid API key"}')
      end

      it 'returns false' do
        expect(provider_instance.validate_connection).to be false
      end

      it 'adds an error' do
        provider_instance.validate_connection
        expect(provider_instance.errors[:base]).to include('Invalid API key')
      end
    end

    context 'with network error' do
      before do
        stub_request(:get, 'https://openrouter.ai/api/v1/models')
          .to_raise(Faraday::ConnectionFailed.new('Connection refused'))
      end

      it 'returns false' do
        expect(provider_instance.validate_connection).to be false
      end

      it 'adds an error with the message' do
        provider_instance.validate_connection
        expect(provider_instance.errors[:base].first).to include('Connection')
      end
    end

    context 'without credentials' do
      let(:integration) { create(:pwb_website_integration, :open_router, :without_credentials, website: website) }

      it 'returns false' do
        expect(provider_instance.validate_connection).to be false
      end

      it 'adds an error about missing API key' do
        provider_instance.validate_connection
        expect(provider_instance.errors[:base].first).to match(/api key/i)
      end
    end
  end

  describe 'integration with Ai::BaseService' do
    let!(:integration) { create(:pwb_website_integration, :open_router, website: website) }

    it 'can be looked up via website.integration_for' do
      expect(website.integration_for(:ai)).to eq(integration)
    end

    it 'provides credentials to the service' do
      expect(integration.credential(:api_key)).to eq('sk-or-test-key-12345')
    end

    it 'provides settings to the service' do
      expect(integration.setting(:default_model)).to eq('anthropic/claude-3.5-sonnet')
    end
  end

  describe 'multi-tenant isolation' do
    let(:website1) { create(:pwb_website) }
    let(:website2) { create(:pwb_website) }
    let!(:integration1) { create(:pwb_website_integration, :open_router, website: website1, credentials: { 'api_key' => 'key-1' }) }
    let!(:integration2) { create(:pwb_website_integration, :open_router, website: website2, credentials: { 'api_key' => 'key-2' }) }

    it 'each website has its own OpenRouter integration' do
      expect(website1.integration_for(:ai).credential(:api_key)).to eq('key-1')
      expect(website2.integration_for(:ai).credential(:api_key)).to eq('key-2')
    end

    it 'integrations are isolated' do
      expect(website1.integrations).not_to include(integration2)
      expect(website2.integrations).not_to include(integration1)
    end
  end
end
