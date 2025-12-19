# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Config do
  describe 'SUPPORTED_LOCALES' do
    it 'includes English as default' do
      expect(described_class::SUPPORTED_LOCALES).to have_key('en')
      expect(described_class::SUPPORTED_LOCALES['en']).to eq('English')
    end

    it 'includes common languages' do
      expect(described_class::SUPPORTED_LOCALES).to have_key('es')
      expect(described_class::SUPPORTED_LOCALES).to have_key('de')
      expect(described_class::SUPPORTED_LOCALES).to have_key('fr')
    end

    it 'uses base locales without regional variants' do
      # SUPPORTED_LOCALES contains only base locales (en, es, fr, etc.)
      # Regional variants (en-UK, en-US) are handled via base_locale() method
      expect(described_class::SUPPORTED_LOCALES.keys).to all(match(/^[a-z]{2}$/))
      expect(described_class::SUPPORTED_LOCALES).not_to have_key('en-UK')
      expect(described_class::SUPPORTED_LOCALES).not_to have_key('en-US')
    end

    it 'is frozen' do
      expect(described_class::SUPPORTED_LOCALES).to be_frozen
    end
  end

  describe 'CURRENCIES' do
    it 'includes major currencies' do
      expect(described_class::CURRENCIES).to have_key('USD')
      expect(described_class::CURRENCIES).to have_key('EUR')
      expect(described_class::CURRENCIES).to have_key('GBP')
    end

    it 'includes label and symbol for each currency' do
      described_class::CURRENCIES.each do |code, info|
        expect(info).to have_key(:label), "#{code} missing :label"
        expect(info).to have_key(:symbol), "#{code} missing :symbol"
      end
    end

    it 'is frozen' do
      expect(described_class::CURRENCIES).to be_frozen
    end
  end

  describe 'AREA_UNITS' do
    it 'includes square meters and square feet' do
      expect(described_class::AREA_UNITS).to have_key('sqmt')
      expect(described_class::AREA_UNITS).to have_key('sqft')
    end

    it 'includes label, abbreviation, and symbol' do
      described_class::AREA_UNITS.each do |code, info|
        expect(info).to have_key(:label), "#{code} missing :label"
        expect(info).to have_key(:abbreviation), "#{code} missing :abbreviation"
        expect(info).to have_key(:symbol), "#{code} missing :symbol"
      end
    end

    it 'is frozen' do
      expect(described_class::AREA_UNITS).to be_frozen
    end
  end

  describe 'FIELD_KEY_CATEGORIES' do
    it 'includes property-types category' do
      expect(described_class::FIELD_KEY_CATEGORIES).to have_key('property-types')
    end

    it 'includes all required category keys' do
      expected_categories = %w[
        property-types
        property-states
        property-features
        property-amenities
        property-status
        property-highlights
        listing-origin
      ]

      expected_categories.each do |category|
        expect(described_class::FIELD_KEY_CATEGORIES).to have_key(category)
      end
    end

    it 'includes required fields for each category' do
      described_class::FIELD_KEY_CATEGORIES.each do |tag, info|
        expect(info).to have_key(:url_key), "#{tag} missing :url_key"
        expect(info).to have_key(:title), "#{tag} missing :title"
        expect(info).to have_key(:short_title), "#{tag} missing :short_title"
        expect(info).to have_key(:description), "#{tag} missing :description"
        expect(info).to have_key(:short_description), "#{tag} missing :short_description"
      end
    end

    it 'is frozen' do
      expect(described_class::FIELD_KEY_CATEGORIES).to be_frozen
    end
  end

  describe '.locale_options_for_select' do
    it 'returns array of [label, code] pairs' do
      options = described_class.locale_options_for_select

      expect(options).to be_an(Array)
      expect(options.first).to eq(['English', 'en'])
    end

    it 'has same number of options as SUPPORTED_LOCALES' do
      expect(described_class.locale_options_for_select.size).to eq(described_class::SUPPORTED_LOCALES.size)
    end
  end

  describe '.locale_label' do
    it 'returns label for known locale' do
      expect(described_class.locale_label('en')).to eq('English')
      expect(described_class.locale_label('es')).to eq('Spanish')
    end

    it 'returns uppercased code for unknown locale' do
      expect(described_class.locale_label('xx')).to eq('XX')
    end

    it 'handles symbol input' do
      expect(described_class.locale_label(:en)).to eq('English')
    end
  end

  describe '.base_locale' do
    it 'returns base locale from regional variant' do
      expect(described_class.base_locale('en-UK')).to eq('en')
      expect(described_class.base_locale('en-US')).to eq('en')
    end

    it 'returns same locale if no variant' do
      expect(described_class.base_locale('es')).to eq('es')
    end

    it 'handles symbol input' do
      expect(described_class.base_locale(:'en-UK')).to eq('en')
    end
  end

  describe '.currency_options_for_select' do
    it 'returns array of formatted options' do
      options = described_class.currency_options_for_select

      expect(options).to be_an(Array)
      expect(options.first[0]).to include(' - ')
      expect(options.first[1]).to match(/^[A-Z]{3}$/)
    end
  end

  describe '.currency_info' do
    it 'returns info hash for known currency' do
      info = described_class.currency_info('USD')

      expect(info).to be_a(Hash)
      expect(info[:label]).to eq('US Dollar')
      expect(info[:symbol]).to eq('$')
    end

    it 'returns nil for unknown currency' do
      expect(described_class.currency_info('XXX')).to be_nil
    end

    it 'handles lowercase input' do
      expect(described_class.currency_info('usd')).not_to be_nil
    end
  end

  describe '.area_unit_options_for_select' do
    it 'returns array of formatted options' do
      options = described_class.area_unit_options_for_select

      expect(options).to be_an(Array)
      expect(options.size).to eq(2)
    end
  end

  describe '.area_unit_info' do
    it 'returns info hash for known unit' do
      info = described_class.area_unit_info('sqmt')

      expect(info).to be_a(Hash)
      expect(info[:label]).to eq('Square Meters')
    end

    it 'returns nil for unknown unit' do
      expect(described_class.area_unit_info('xxx')).to be_nil
    end
  end

  describe '.field_key_category' do
    it 'returns category info by database tag' do
      info = described_class.field_key_category('property-types')

      expect(info).to be_a(Hash)
      expect(info[:url_key]).to eq('property_types')
      expect(info[:title]).to eq('Property Types')
    end

    it 'returns nil for unknown tag' do
      expect(described_class.field_key_category('unknown-tag')).to be_nil
    end
  end

  describe '.field_key_category_by_url' do
    it 'returns category info by URL key' do
      info = described_class.field_key_category_by_url('property_types')

      expect(info).to be_a(Hash)
      expect(info[:tag]).to eq('property-types')
      expect(info[:title]).to eq('Property Types')
    end

    it 'returns nil for unknown URL key' do
      expect(described_class.field_key_category_by_url('unknown_key')).to be_nil
    end
  end

  describe '.field_key_url_to_tag_mapping' do
    it 'returns hash mapping URL keys to database tags' do
      mapping = described_class.field_key_url_to_tag_mapping

      expect(mapping).to be_a(Hash)
      expect(mapping['property_types']).to eq('property-types')
      expect(mapping['property_features']).to eq('property-features')
    end
  end

  describe '.field_key_category_tags' do
    it 'returns array of all category tags' do
      tags = described_class.field_key_category_tags

      expect(tags).to be_an(Array)
      expect(tags).to include('property-types')
      expect(tags).to include('property-features')
    end
  end

  describe '.build_locale_details' do
    it 'builds locale details from array of locales' do
      details = described_class.build_locale_details(['en', 'es'])

      expect(details).to be_an(Array)
      expect(details.size).to eq(2)
      expect(details.first[:locale]).to eq('en')
      expect(details.first[:label]).to eq('English')
    end

    it 'handles regional variants' do
      details = described_class.build_locale_details(['en-UK'])

      expect(details.first[:locale]).to eq('en')
      expect(details.first[:variant]).to eq('UK')
      expect(details.first[:full]).to eq('en-UK')
    end

    it 'filters out blank values' do
      details = described_class.build_locale_details(['en', '', nil, 'es'])

      expect(details.size).to eq(2)
      expect(details.map { |d| d[:locale] }).to eq(%w[en es])
    end

    it 'returns empty array for blank input' do
      expect(described_class.build_locale_details(nil)).to eq([])
      expect(described_class.build_locale_details([])).to eq([])
    end
  end
end
