# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::Registry do
  describe '.register' do
    it 'registers a provider for a category' do
      # The providers are already registered via the initializer
      # Just verify the structure exists
      expect(described_class.categories).to include(:ai)
    end
  end

  describe '.provider' do
    it 'returns the provider class for valid category and provider' do
      expect(described_class.provider(:ai, :anthropic)).to eq(Integrations::Providers::Anthropic)
    end

    it 'returns nil for unknown provider' do
      expect(described_class.provider(:ai, :unknown)).to be_nil
    end

    it 'returns nil for unknown category' do
      expect(described_class.provider(:unknown, :anthropic)).to be_nil
    end

    it 'accepts string arguments' do
      expect(described_class.provider('ai', 'anthropic')).to eq(Integrations::Providers::Anthropic)
    end
  end

  describe '.providers_for' do
    it 'returns all providers for a category' do
      providers = described_class.providers_for(:ai)
      expect(providers).to be_a(Hash)
      expect(providers).to include(:anthropic, :openai)
    end

    it 'returns empty hash for unknown category' do
      expect(described_class.providers_for(:unknown)).to eq({})
    end
  end

  describe '.categories' do
    it 'returns all registered categories' do
      expect(described_class.categories).to include(:ai)
    end
  end

  describe 'Anthropic provider' do
    let(:provider) { described_class.provider(:ai, :anthropic) }

    it 'has correct display name' do
      expect(provider.display_name).to eq('Anthropic')
    end

    it 'has correct category' do
      expect(provider.category).to eq(:ai)
    end

    it 'defines required api_key credential' do
      expect(provider.credential_fields[:api_key][:required]).to be true
    end

    it 'defines default_model setting' do
      expect(provider.setting_fields[:default_model]).to be_present
      expect(provider.default_for(:default_model)).to eq('claude-sonnet-4-20250514')
    end

    it 'defines max_tokens setting' do
      expect(provider.setting_fields[:max_tokens]).to be_present
      expect(provider.default_for(:max_tokens)).to eq(4096)
    end
  end

  describe 'OpenAI provider' do
    let(:provider) { described_class.provider(:ai, :openai) }

    it 'has correct display name' do
      expect(provider.display_name).to eq('OpenAI')
    end

    it 'has correct category' do
      expect(provider.category).to eq(:ai)
    end

    it 'defines required api_key credential' do
      expect(provider.credential_fields[:api_key][:required]).to be true
    end

    it 'defines optional organization_id credential' do
      expect(provider.credential_fields[:organization_id][:required]).to be false
    end

    it 'defines default_model setting' do
      expect(provider.default_for(:default_model)).to eq('gpt-4o-mini')
    end
  end
end
