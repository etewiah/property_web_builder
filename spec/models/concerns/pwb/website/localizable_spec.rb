# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::WebsiteLocalizable, type: :model do
  let(:website) { create(:pwb_website) }

  around do |example|
    ActsAsTenant.with_tenant(website) do
      example.run
    end
  end

  describe 'validations' do
    describe 'default_locale_in_supported_locales' do
      it 'is valid when default locale is in supported locales' do
        website.supported_locales = %w[en-UK fr-FR]
        website.default_client_locale = 'en-UK'
        expect(website).to be_valid
      end

      it 'is valid when comparing base locale codes' do
        website.supported_locales = %w[en-UK fr-FR]
        website.default_client_locale = 'en-US'
        expect(website).to be_valid
      end

      it 'is invalid when default locale is not in supported locales' do
        website.supported_locales = %w[en-UK fr-FR]
        website.default_client_locale = 'de-DE'
        expect(website).not_to be_valid
        expect(website.errors[:default_client_locale]).to include('must be one of the supported languages')
      end

      it 'skips validation when default_client_locale is blank' do
        website.supported_locales = ['en-UK']
        website.default_client_locale = nil
        expect(website).to be_valid
      end

      it 'skips validation when supported_locales is blank' do
        website.supported_locales = []
        website.default_client_locale = 'en-UK'
        expect(website).to be_valid
      end

      it 'ignores blank entries in supported_locales' do
        website.supported_locales = ['en-UK', '', 'fr-FR']
        website.default_client_locale = 'en-UK'
        expect(website).to be_valid
      end
    end
  end

  describe '#is_multilingual' do
    it 'returns false for single locale' do
      website.supported_locales = ['en-UK']
      expect(website.is_multilingual).to be false
    end

    it 'returns true for multiple locales' do
      website.supported_locales = %w[en-UK fr-FR]
      expect(website.is_multilingual).to be true
    end

    it 'ignores blank entries' do
      website.supported_locales = ['en-UK', '', '']
      expect(website.is_multilingual).to be false
    end
  end

  describe '#supported_locales_with_variants' do
    it 'parses locale with variant' do
      website.supported_locales = ['en-UK']
      result = website.supported_locales_with_variants

      expect(result).to eq([{ 'locale' => 'en', 'variant' => 'uk' }])
    end

    it 'handles locale without variant' do
      website.supported_locales = ['fr']
      result = website.supported_locales_with_variants

      expect(result).to eq([{ 'locale' => 'fr', 'variant' => 'fr' }])
    end

    it 'parses multiple locales' do
      website.supported_locales = %w[en-UK fr-FR de-DE]
      result = website.supported_locales_with_variants

      expect(result).to eq([
                             { 'locale' => 'en', 'variant' => 'uk' },
                             { 'locale' => 'fr', 'variant' => 'fr' },
                             { 'locale' => 'de', 'variant' => 'de' }
                           ])
    end

    it 'filters out blank entries' do
      website.supported_locales = ['en-UK', '', 'fr-FR']
      result = website.supported_locales_with_variants

      expect(result.length).to eq(2)
    end
  end

  describe '#default_client_locale_to_use' do
    it 'returns base locale code from default' do
      website.default_client_locale = 'en-UK'
      expect(website.default_client_locale_to_use).to eq('en')
    end

    it 'uses first supported locale when only one exists' do
      website.supported_locales = ['fr-FR']
      website.default_client_locale = 'en-UK'
      expect(website.default_client_locale_to_use).to eq('fr')
    end

    it 'falls back to en-UK when default is nil' do
      website.default_client_locale = nil
      expect(website.default_client_locale_to_use).to eq('en')
    end
  end
end
