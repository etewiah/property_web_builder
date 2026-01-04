# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe SearchFilterOption, type: :model do
    let(:website) { create(:pwb_website, subdomain: 'testsite') }
    let(:website_b) { create(:pwb_website, subdomain: 'othersite') }

    describe 'validations' do
      it 'is valid with required attributes' do
        option = SearchFilterOption.new(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'apartment'
        )
        expect(option).to be_valid
      end

      it 'requires website' do
        option = SearchFilterOption.new(
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'apartment'
        )
        expect(option).not_to be_valid
        expect(option.errors[:website]).to include('must exist')
      end

      it 'requires filter_type' do
        option = SearchFilterOption.new(
          website: website,
          global_key: 'apartment'
        )
        expect(option).not_to be_valid
        expect(option.errors[:filter_type]).to include("can't be blank")
      end

      it 'validates filter_type inclusion' do
        option = SearchFilterOption.new(
          website: website,
          filter_type: 'invalid_type',
          global_key: 'apartment'
        )
        expect(option).not_to be_valid
        expect(option.errors[:filter_type]).to include('is not included in the list')
      end

      it 'requires global_key' do
        option = SearchFilterOption.new(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE
        )
        expect(option).not_to be_valid
        expect(option.errors[:global_key]).to include("can't be blank")
      end

      it 'validates global_key format' do
        option = SearchFilterOption.new(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'Invalid Key!'
        )
        expect(option).not_to be_valid
        expect(option.errors[:global_key]).to include('only allows lowercase letters, numbers, hyphens, and underscores')
      end

      it 'allows valid global_key formats' do
        %w[apartment villa-detached ground_floor apt123].each do |key|
          option = SearchFilterOption.new(
            website: website,
            filter_type: SearchFilterOption::PROPERTY_TYPE,
            global_key: key
          )
          expect(option).to be_valid, "Expected '#{key}' to be valid"
        end
      end

      describe 'uniqueness scoped by website and filter_type' do
        before do
          SearchFilterOption.create!(
            website: website,
            filter_type: SearchFilterOption::PROPERTY_TYPE,
            global_key: 'apartment'
          )
        end

        it 'allows same global_key in different websites' do
          option = SearchFilterOption.new(
            website: website_b,
            filter_type: SearchFilterOption::PROPERTY_TYPE,
            global_key: 'apartment'
          )
          expect(option).to be_valid
        end

        it 'allows same global_key in different filter types' do
          option = SearchFilterOption.new(
            website: website,
            filter_type: SearchFilterOption::FEATURE,
            global_key: 'apartment'
          )
          expect(option).to be_valid
        end

        it 'prevents duplicate global_key within same website and filter_type' do
          option = SearchFilterOption.new(
            website: website,
            filter_type: SearchFilterOption::PROPERTY_TYPE,
            global_key: 'apartment'
          )
          expect(option).not_to be_valid
          expect(option.errors[:global_key]).to include('has already been taken')
        end
      end
    end

    describe 'associations' do
      it 'belongs to website' do
        option = SearchFilterOption.new(website: website)
        expect(option.website).to eq(website)
      end

      it 'belongs to parent (optional)' do
        parent = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'villa'
        )
        child = SearchFilterOption.new(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'detached-villa',
          parent: parent
        )
        expect(child).to be_valid
        expect(child.parent).to eq(parent)
      end

      it 'has many children' do
        parent = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'villa'
        )
        child1 = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'detached-villa',
          parent: parent
        )
        child2 = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'semi-detached-villa',
          parent: parent
        )
        expect(parent.children).to include(child1, child2)
      end
    end

    describe 'scopes' do
      before do
        @property_type = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'apartment',
          visible: true,
          show_in_search: true
        )
        @feature = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::FEATURE,
          global_key: 'pool',
          visible: true,
          show_in_search: true
        )
        @hidden = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'hidden-type',
          visible: false,
          show_in_search: false
        )
      end

      describe '.property_types' do
        it 'returns only property type options' do
          result = SearchFilterOption.property_types
          expect(result).to include(@property_type, @hidden)
          expect(result).not_to include(@feature)
        end
      end

      describe '.features' do
        it 'returns only feature options' do
          result = SearchFilterOption.features
          expect(result).to include(@feature)
          expect(result).not_to include(@property_type)
        end
      end

      describe '.visible' do
        it 'returns only visible options' do
          result = SearchFilterOption.visible
          expect(result).to include(@property_type, @feature)
          expect(result).not_to include(@hidden)
        end
      end

      describe '.show_in_search' do
        it 'returns only options marked for search' do
          result = SearchFilterOption.show_in_search
          expect(result).to include(@property_type, @feature)
          expect(result).not_to include(@hidden)
        end
      end

      describe '.roots' do
        it 'returns only options without parents' do
          parent = SearchFilterOption.create!(
            website: website,
            filter_type: SearchFilterOption::PROPERTY_TYPE,
            global_key: 'villa'
          )
          child = SearchFilterOption.create!(
            website: website,
            filter_type: SearchFilterOption::PROPERTY_TYPE,
            global_key: 'child-villa',
            parent: parent
          )

          result = SearchFilterOption.roots
          expect(result).to include(@property_type, @feature, parent)
          expect(result).not_to include(child)
        end
      end
    end

    describe '#display_label' do
      it 'returns the translation for current locale' do
        option = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'apartment',
          translations: { 'en' => 'Apartment', 'es' => 'Apartamento' }
        )

        I18n.with_locale(:en) do
          expect(option.display_label).to eq('Apartment')
        end

        I18n.with_locale(:es) do
          expect(option.display_label).to eq('Apartamento')
        end
      end

      it 'falls back to English when translation missing' do
        option = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'apartment',
          translations: { 'en' => 'Apartment' }
        )

        I18n.with_locale(:fr) do
          expect(option.display_label).to eq('Apartment')
        end
      end

      it 'falls back to global_key titleized when no translations' do
        option = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'luxury-apartment'
        )

        expect(option.display_label).to eq('Luxury Apartment')
      end
    end

    describe '#external_mapping_for' do
      it 'returns external_code as default' do
        option = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'apartment',
          external_code: '1-1'
        )

        expect(option.external_mapping_for('resales_online')).to eq('1-1')
      end

      it 'returns provider-specific mapping if exists' do
        option = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'apartment',
          external_code: '1-1',
          metadata: {
            'external_mappings' => {
              'other_provider' => 'APT'
            }
          }
        )

        expect(option.external_mapping_for('other_provider')).to eq('APT')
        expect(option.external_mapping_for('resales_online')).to eq('1-1')
      end
    end

    describe '#to_option' do
      it 'returns hash with value and label' do
        option = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'apartment',
          external_code: '1-1',
          translations: { 'en' => 'Apartment' }
        )

        result = option.to_option
        expect(result[:value]).to eq('apartment')
        expect(result[:label]).to eq('Apartment')
        expect(result[:external_code]).to eq('1-1')
      end
    end

    describe '.import_options' do
      it 'creates new options from array' do
        options_data = [
          { value: 'apartment', label: 'Apartment', external_code: '1-1' },
          { value: 'villa', label: 'Villa', external_code: '1-2' }
        ]

        result = SearchFilterOption.import_options(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          options: options_data
        )

        expect(result.size).to eq(2)
        expect(SearchFilterOption.count).to eq(2)
      end

      it 'does not duplicate existing options' do
        SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'apartment',
          external_code: '1-1'
        )

        options_data = [
          { value: 'apartment', label: 'Apartment', external_code: '1-1' },
          { value: 'villa', label: 'Villa', external_code: '1-2' }
        ]

        result = SearchFilterOption.import_options(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          options: options_data
        )

        expect(result.size).to eq(2)
        expect(SearchFilterOption.count).to eq(2)
      end
    end

    describe 'callback: generate_global_key' do
      it 'generates global_key from English translation' do
        option = SearchFilterOption.new(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          translations: { 'en' => 'Luxury Apartment' }
        )
        option.valid?

        expect(option.global_key).to eq('luxury-apartment')
      end

      it 'does not override existing global_key' do
        option = SearchFilterOption.new(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'custom-key',
          translations: { 'en' => 'Luxury Apartment' }
        )
        option.valid?

        expect(option.global_key).to eq('custom-key')
      end
    end

    describe '#feature_param_name' do
      it 'returns param_name from metadata for features' do
        option = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::FEATURE,
          global_key: 'pool',
          metadata: { 'param_name' => 'p_Pool' }
        )

        expect(option.feature_param_name).to eq('p_Pool')
      end

      it 'returns nil for non-features' do
        option = SearchFilterOption.create!(
          website: website,
          filter_type: SearchFilterOption::PROPERTY_TYPE,
          global_key: 'apartment',
          metadata: { 'param_name' => 'p_Type' }
        )

        expect(option.feature_param_name).to be_nil
      end
    end
  end
end
