# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::WebsiteIntegration, type: :model do
  describe 'hpg category' do
    let!(:website) { create(:pwb_website) }

    it 'accepts hpg as a valid category' do
      integration = website.integrations.build(
        category: 'hpg',
        provider: 'house_price_guess',
        credentials: { 'api_key' => SecureRandom.hex(32) },
        enabled: true
      )
      expect(integration).to be_valid
    end

    it 'returns category info for hpg' do
      info = described_class.category_info(:hpg)
      expect(info[:name]).to eq('House Price Guess')
      expect(info[:icon]).to eq('game-controller')
    end

    it 'includes hpg in category_names' do
      expect(described_class.category_names).to include(hpg: 'House Price Guess')
    end

    it 'can create an hpg integration with credentials' do
      integration = website.integrations.create!(
        category: 'hpg',
        provider: 'house_price_guess',
        credentials: { 'api_key' => 'test-hpg-key-123' },
        enabled: true
      )

      expect(integration).to be_persisted
      expect(integration.credential('api_key')).to eq('test-hpg-key-123')
      expect(integration.category_name).to eq('House Price Guess')
      expect(integration.status).to eq(:connected)
    end

    it 'enforces unique provider per website and category' do
      website.integrations.create!(
        category: 'hpg',
        provider: 'house_price_guess',
        credentials: { 'api_key' => 'key1' },
        enabled: true
      )

      duplicate = website.integrations.build(
        category: 'hpg',
        provider: 'house_price_guess',
        credentials: { 'api_key' => 'key2' },
        enabled: true
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:provider]).to include('already configured for this category')
    end
  end
end
