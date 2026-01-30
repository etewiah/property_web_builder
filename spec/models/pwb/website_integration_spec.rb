# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::WebsiteIntegration, type: :model do
  let(:website) { create(:pwb_website) }

  describe 'validations' do
    it 'requires category' do
      integration = build(:pwb_website_integration, website: website, category: nil)
      expect(integration).not_to be_valid
      expect(integration.errors[:category]).to include("can't be blank")
    end

    it 'requires provider' do
      integration = build(:pwb_website_integration, website: website, provider: nil)
      expect(integration).not_to be_valid
      expect(integration.errors[:provider]).to include("can't be blank")
    end

    it 'validates category inclusion' do
      integration = build(:pwb_website_integration, website: website, category: 'invalid')
      expect(integration).not_to be_valid
      expect(integration.errors[:category]).to include('is not included in the list')
    end

    it 'enforces unique provider per category per website' do
      create(:pwb_website_integration, :anthropic, website: website)
      duplicate = build(:pwb_website_integration, :anthropic, website: website)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:provider]).to include('already configured for this category')
    end

    it 'allows same provider on different websites' do
      other_website = create(:pwb_website)
      create(:pwb_website_integration, :anthropic, website: website)
      integration = build(:pwb_website_integration, :anthropic, website: other_website)

      expect(integration).to be_valid
    end

    it 'allows different providers in same category' do
      create(:pwb_website_integration, :anthropic, website: website)
      integration = build(:pwb_website_integration, :openai, website: website)

      expect(integration).to be_valid
    end
  end

  describe 'scopes' do
    let!(:enabled_integration) { create(:pwb_website_integration, :anthropic, website: website, enabled: true) }
    let!(:disabled_integration) { create(:pwb_website_integration, :openai, website: website, enabled: false) }

    describe '.enabled' do
      it 'returns only enabled integrations' do
        expect(described_class.enabled).to include(enabled_integration)
        expect(described_class.enabled).not_to include(disabled_integration)
      end
    end

    describe '.disabled' do
      it 'returns only disabled integrations' do
        expect(described_class.disabled).to include(disabled_integration)
        expect(described_class.disabled).not_to include(enabled_integration)
      end
    end

    describe '.for_category' do
      it 'filters by category' do
        expect(described_class.for_category(:ai)).to include(enabled_integration, disabled_integration)
      end
    end

    describe '.by_provider' do
      it 'filters by provider' do
        expect(described_class.by_provider(:anthropic)).to include(enabled_integration)
        expect(described_class.by_provider(:anthropic)).not_to include(disabled_integration)
      end
    end
  end

  describe 'credential management' do
    let(:integration) { create(:pwb_website_integration, :anthropic, website: website) }

    describe '#credential' do
      it 'returns credential value' do
        expect(integration.credential(:api_key)).to eq('test-anthropic-key')
      end

      it 'returns nil for missing credential' do
        expect(integration.credential(:missing)).to be_nil
      end

      it 'accepts string keys' do
        expect(integration.credential('api_key')).to eq('test-anthropic-key')
      end
    end

    describe '#set_credential' do
      it 'sets credential value' do
        integration.set_credential(:new_key, 'new_value')
        expect(integration.credential(:new_key)).to eq('new_value')
      end

      it 'initializes credentials hash if nil' do
        integration.credentials = nil
        integration.set_credential(:api_key, 'value')
        expect(integration.credentials).to eq({ 'api_key' => 'value' })
      end
    end

    describe '#credentials_present?' do
      it 'returns true when credentials have values' do
        expect(integration.credentials_present?).to be true
      end

      it 'returns false when credentials empty' do
        integration.credentials = {}
        expect(integration.credentials_present?).to be false
      end

      it 'returns false when credentials nil' do
        integration.credentials = nil
        expect(integration.credentials_present?).to be false
      end
    end

    describe '#masked_credential' do
      it 'masks long credentials showing last 4 characters' do
        integration.set_credential(:api_key, 'sk-1234567890abcdef')
        expect(integration.masked_credential(:api_key)).to eq('••••••••cdef')
      end

      it 'fully masks short credentials' do
        integration.set_credential(:api_key, 'short')
        expect(integration.masked_credential(:api_key)).to eq('••••••••')
      end

      it 'returns nil for missing credentials' do
        expect(integration.masked_credential(:missing)).to be_nil
      end
    end
  end

  describe 'settings management' do
    let(:integration) { create(:pwb_website_integration, :anthropic, website: website) }

    describe '#setting' do
      it 'returns setting value' do
        expect(integration.setting(:default_model)).to eq('claude-sonnet-4-20250514')
      end

      it 'falls back to provider default' do
        integration.settings = {}
        expect(integration.setting(:default_model)).to eq('claude-sonnet-4-20250514')
      end
    end

    describe '#set_setting' do
      it 'sets setting value' do
        integration.set_setting(:max_tokens, 8192)
        expect(integration.setting(:max_tokens)).to eq(8192)
      end
    end
  end

  describe 'provider integration' do
    let(:integration) { create(:pwb_website_integration, :anthropic, website: website) }

    describe '#provider_definition' do
      it 'returns the provider class' do
        expect(integration.provider_definition).to eq(Integrations::Providers::Anthropic)
      end

      it 'returns nil for unknown provider' do
        integration.provider = 'unknown'
        expect(integration.provider_definition).to be_nil
      end
    end

    describe '#provider_name' do
      it 'returns display name from provider' do
        expect(integration.provider_name).to eq('Anthropic')
      end

      it 'falls back to titleized provider for unknown' do
        integration.provider = 'unknown_provider'
        expect(integration.provider_name).to eq('Unknown Provider')
      end
    end
  end

  describe 'status tracking' do
    let(:integration) { create(:pwb_website_integration, :anthropic, website: website) }

    describe '#record_usage!' do
      it 'updates last_used_at' do
        expect(integration.last_used_at).to be_nil
        integration.record_usage!
        expect(integration.reload.last_used_at).to be_present
        expect(integration.last_used_at).to be_within(5.seconds).of(Time.current)
      end
    end

    describe '#record_error!' do
      it 'records error with timestamp and message' do
        integration.record_error!('API error')
        integration.reload
        expect(integration.last_error_at).to be_present
        expect(integration.last_error_at).to be_within(5.seconds).of(Time.current)
        expect(integration.last_error_message).to eq('API error')
      end
    end

    describe '#clear_error!' do
      let(:integration) { create(:pwb_website_integration, :with_error, website: website) }

      it 'clears error fields' do
        integration.clear_error!
        integration.reload
        expect(integration.last_error_at).to be_nil
        expect(integration.last_error_message).to be_nil
      end
    end

    describe '#status' do
      it 'returns :connected for enabled with credentials and no errors' do
        expect(integration.status).to eq(:connected)
      end

      it 'returns :disabled when not enabled' do
        integration.enabled = false
        expect(integration.status).to eq(:disabled)
      end

      it 'returns :error when has error' do
        integration.last_error_at = Time.current
        expect(integration.status).to eq(:error)
      end

      it 'returns :not_configured without credentials' do
        integration.credentials = {}
        expect(integration.status).to eq(:not_configured)
      end
    end

    describe '#connected?' do
      it 'returns true when enabled, has credentials, and no errors' do
        expect(integration.connected?).to be true
      end

      it 'returns false when disabled' do
        integration.enabled = false
        expect(integration.connected?).to be false
      end

      it 'returns false when has error' do
        integration.last_error_at = Time.current
        expect(integration.connected?).to be false
      end
    end
  end

  describe 'encryption' do
    let(:integration) { create(:pwb_website_integration, :anthropic, website: website) }

    it 'encrypts credentials at rest' do
      # The credential value should be accessible
      expect(integration.credential(:api_key)).to eq('test-anthropic-key')

      # But the raw database value should be encrypted (not the plaintext)
      raw_value = Pwb::WebsiteIntegration.connection.execute(
        "SELECT credentials FROM pwb_website_integrations WHERE id = #{integration.id}"
      ).first['credentials']

      expect(raw_value).not_to include('test-anthropic-key')
    end
  end
end
