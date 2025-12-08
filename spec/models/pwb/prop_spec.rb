# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe Prop, type: :model do
    let(:website) { create(:pwb_website, subdomain: 'prop-test', default_currency: 'USD') }

    describe 'factory' do
      it 'creates a valid prop' do
        prop = build(:pwb_prop, website: website)
        expect(prop).to be_valid
      end

      it 'creates a sale property with trait' do
        prop = create(:pwb_prop, :sale, website: website)
        expect(prop.for_sale).to be_truthy
      end

      it 'creates a rental property with trait' do
        prop = create(:pwb_prop, :long_term_rent, website: website)
        expect(prop.for_rent_long_term).to be_truthy
      end
    end

    describe 'associations' do
      it 'belongs to website' do
        prop = create(:pwb_prop, website: website)
        expect(prop.website).to eq(website)
      end

      it 'has many prop_photos' do
        prop = create(:pwb_prop, website: website)
        expect(prop).to respond_to(:prop_photos)
      end

      it 'has many features' do
        prop = create(:pwb_prop, website: website)
        expect(prop).to respond_to(:features)
      end
    end

    describe 'scopes' do
      let!(:sale_prop) { create(:pwb_prop, :sale, website: website, visible: true) }
      let!(:rental_prop) { create(:pwb_prop, :long_term_rent, website: website, visible: true) }
      let!(:hidden_prop) { create(:pwb_prop, :sale, website: website, visible: false) }

      describe '.for_sale' do
        it 'returns properties for sale' do
          expect(Prop.for_sale).to include(sale_prop)
          expect(Prop.for_sale).not_to include(rental_prop)
        end
      end

      describe '.for_rent' do
        it 'returns rental properties' do
          expect(Prop.for_rent).to include(rental_prop)
          expect(Prop.for_rent).not_to include(sale_prop)
        end
      end

      describe '.visible' do
        it 'returns only visible properties' do
          expect(Prop.visible).to include(sale_prop)
          expect(Prop.visible).to include(rental_prop)
          expect(Prop.visible).not_to include(hidden_prop)
        end
      end
    end

    describe 'price scopes' do
      let!(:cheap_prop) { create(:pwb_prop, :sale, website: website, visible: true, price_sale_current_cents: 100_000_00) }
      let!(:expensive_prop) { create(:pwb_prop, :sale, website: website, visible: true, price_sale_current_cents: 500_000_00) }

      describe '.for_sale_price_from' do
        it 'filters by minimum price' do
          results = Prop.for_sale_price_from(200_000_00)
          expect(results).to include(expensive_prop)
          expect(results).not_to include(cheap_prop)
        end
      end

      describe '.for_sale_price_till' do
        it 'filters by maximum price' do
          results = Prop.for_sale_price_till(200_000_00)
          expect(results).to include(cheap_prop)
          expect(results).not_to include(expensive_prop)
        end
      end
    end

    describe 'bedroom/bathroom scopes' do
      let!(:small_prop) { create(:pwb_prop, website: website, count_bedrooms: 1, count_bathrooms: 1) }
      let!(:large_prop) { create(:pwb_prop, website: website, count_bedrooms: 4, count_bathrooms: 3) }

      describe '.bedrooms_from' do
        it 'filters by minimum bedrooms' do
          results = Prop.bedrooms_from(3)
          expect(results).to include(large_prop)
          expect(results).not_to include(small_prop)
        end
      end

      describe '.bathrooms_from' do
        it 'filters by minimum bathrooms' do
          results = Prop.bathrooms_from(2)
          expect(results).to include(large_prop)
          expect(results).not_to include(small_prop)
        end
      end
    end

    describe '#for_rent' do
      it 'returns true for short term rental' do
        prop = build(:pwb_prop, for_rent_short_term: true, for_rent_long_term: false)
        expect(prop.for_rent).to be_truthy
      end

      it 'returns true for long term rental' do
        prop = build(:pwb_prop, for_rent_short_term: false, for_rent_long_term: true)
        expect(prop.for_rent).to be_truthy
      end

      it 'returns false when not for rent' do
        prop = build(:pwb_prop, for_rent_short_term: false, for_rent_long_term: false)
        expect(prop.for_rent).to be_falsey
      end
    end

    describe '#has_garage' do
      it 'returns true when count_garages is positive' do
        prop = build(:pwb_prop, count_garages: 2)
        expect(prop.has_garage).to be_truthy
      end

      it 'returns false when count_garages is zero' do
        prop = build(:pwb_prop, count_garages: 0)
        expect(prop.has_garage).to be_falsey
      end

      it 'returns false when count_garages is nil' do
        prop = build(:pwb_prop, count_garages: nil)
        expect(prop.has_garage).to be_falsey
      end
    end

    describe '#show_map' do
      it 'returns true when coordinates exist and map not hidden' do
        prop = build(:pwb_prop, latitude: 40.0, longitude: -3.0, hide_map: false)
        expect(prop.show_map).to be_truthy
      end

      it 'returns false when hide_map is true' do
        prop = build(:pwb_prop, latitude: 40.0, longitude: -3.0, hide_map: true)
        expect(prop.show_map).to be_falsey
      end

      it 'returns false when latitude is missing' do
        prop = build(:pwb_prop, latitude: nil, longitude: -3.0, hide_map: false)
        expect(prop.show_map).to be_falsey
      end

      it 'returns false when longitude is missing' do
        prop = build(:pwb_prop, latitude: 40.0, longitude: nil, hide_map: false)
        expect(prop.show_map).to be_falsey
      end
    end

    describe '#geocodeable_address' do
      it 'combines address components' do
        prop = build(:pwb_prop,
                     street_address: '123 Main St',
                     city: 'Madrid',
                     province: 'Madrid',
                     postal_code: '28001')
        expect(prop.geocodeable_address).to eq('123 Main St , Madrid , Madrid , 28001')
      end
    end

    describe '#needs_geocoding?' do
      it 'returns true when address exists but no coordinates' do
        prop = build(:pwb_prop,
                     street_address: '123 Main St',
                     city: 'Madrid',
                     latitude: nil,
                     longitude: nil)
        expect(prop.needs_geocoding?).to be_truthy
      end

      it 'returns false when coordinates exist' do
        prop = build(:pwb_prop,
                     street_address: '123 Main St',
                     city: 'Madrid',
                     latitude: 40.0,
                     longitude: -3.0)
        expect(prop.needs_geocoding?).to be_falsey
      end
    end

    describe '#url_friendly_title' do
      it 'parameterizes the title' do
        prop = build(:pwb_prop, title_en: 'Beautiful Beach House')
        expect(prop.url_friendly_title).to eq('beautiful-beach-house')
      end

      it 'returns show for short or nil titles' do
        prop = build(:pwb_prop, title_en: 'AB')
        expect(prop.url_friendly_title).to eq('show')
      end
    end

    describe 'features management' do
      let(:prop) { create(:pwb_prop, website: website) }

      describe '#set_features=' do
        it 'creates features when set to true' do
          prop.set_features = { 'pool' => true, 'garage' => true }

          expect(prop.features.pluck(:feature_key)).to include('pool', 'garage')
        end

        it 'removes features when set to false' do
          prop.set_features = { 'pool' => true }
          expect(prop.features.pluck(:feature_key)).to include('pool')

          prop.set_features = { 'pool' => false }
          expect(prop.features.pluck(:feature_key)).not_to include('pool')
        end
      end

      describe '#get_features' do
        it 'returns hash of feature keys' do
          prop.features.create!(feature_key: 'pool')
          prop.features.create!(feature_key: 'garden')

          features = prop.get_features
          expect(features).to include('pool' => true, 'garden' => true)
        end
      end
    end

    describe '#contextual_price' do
      let(:prop) do
        create(:pwb_prop, website: website,
                          for_sale: true,
                          for_rent_long_term: true,
                          price_sale_current_cents: 500_000_00,
                          price_rental_monthly_for_search_cents: 1_500_00)
      end

      it 'returns sale price when for_sale context' do
        price = prop.contextual_price('for_sale')
        expect(price.cents).to eq(500_000_00)
      end

      it 'returns rental price when for_rent context' do
        price = prop.contextual_price('for_rent')
        expect(price.cents).to eq(1_500_00)
      end
    end

    describe '.properties_search' do
      let!(:sale_visible) { create(:pwb_prop, :sale, website: website, visible: true, price_sale_current_cents: 200_000_00) }
      let!(:sale_hidden) { create(:pwb_prop, :sale, website: website, visible: false, price_sale_current_cents: 200_000_00) }
      let!(:rental_visible) { create(:pwb_prop, :long_term_rent, website: website, visible: true) }

      it 'returns visible sale properties for sale search' do
        results = Prop.properties_search(sale_or_rental: 'sale')
        expect(results).to include(sale_visible)
        expect(results).not_to include(sale_hidden)
        expect(results).not_to include(rental_visible)
      end

      it 'returns visible rental properties for rental search' do
        results = Prop.properties_search(sale_or_rental: 'rental')
        expect(results).to include(rental_visible)
        expect(results).not_to include(sale_visible)
      end
    end

    describe 'translations' do
      let(:prop) { create(:pwb_prop, website: website, title_en: 'English Title') }

      it 'supports multiple locales for title' do
        prop.title_es = 'Spanish Title'
        prop.save!

        I18n.with_locale(:en) { expect(prop.title).to eq('English Title') }
        I18n.with_locale(:es) { expect(prop.title).to eq('Spanish Title') }
      end

      it 'supports multiple locales for description' do
        prop.description_en = 'English Description'
        prop.description_es = 'Spanish Description'
        prop.save!

        I18n.with_locale(:en) { expect(prop.description).to eq('English Description') }
        I18n.with_locale(:es) { expect(prop.description).to eq('Spanish Description') }
      end
    end
  end
end
