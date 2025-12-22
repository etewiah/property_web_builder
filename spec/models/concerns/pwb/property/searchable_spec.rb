# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::PropertySearchable, type: :model do
  let(:website) { create(:pwb_website) }

  describe 'scopes' do
    let!(:sale_property) { create(:pwb_prop, website: website, for_sale: true, visible: true) }
    let!(:rent_property) { create(:pwb_prop, website: website, for_rent_long_term: true, visible: true) }
    let!(:hidden_property) { create(:pwb_prop, website: website, for_sale: true, visible: false) }

    describe '.for_sale' do
      it 'returns properties for sale' do
        expect(Pwb::Prop.for_sale).to include(sale_property)
        expect(Pwb::Prop.for_sale).not_to include(rent_property)
      end
    end

    describe '.for_rent' do
      it 'returns properties for rent (long or short term)' do
        expect(Pwb::Prop.for_rent).to include(rent_property)
        expect(Pwb::Prop.for_rent).not_to include(sale_property)
      end

      it 'includes short term rentals' do
        short_term = create(:pwb_prop, website: website, for_rent_short_term: true)
        expect(Pwb::Prop.for_rent).to include(short_term)
      end
    end

    describe '.visible' do
      it 'returns only visible properties' do
        expect(Pwb::Prop.visible).to include(sale_property, rent_property)
        expect(Pwb::Prop.visible).not_to include(hidden_property)
      end
    end
  end

  describe 'price filter scopes' do
    let!(:cheap_sale) { create(:pwb_prop, website: website, for_sale: true, price_sale_current_cents: 100_000_00) }
    let!(:expensive_sale) { create(:pwb_prop, website: website, for_sale: true, price_sale_current_cents: 500_000_00) }
    let!(:cheap_rent) { create(:pwb_prop, website: website, for_rent_long_term: true, price_rental_monthly_for_search_cents: 1000_00) }
    let!(:expensive_rent) { create(:pwb_prop, website: website, for_rent_long_term: true, price_rental_monthly_for_search_cents: 3000_00) }

    describe '.for_sale_price_from' do
      it 'filters properties above minimum sale price' do
        result = Pwb::Prop.for_sale_price_from(200_000_00)
        expect(result).to include(expensive_sale)
        expect(result).not_to include(cheap_sale)
      end
    end

    describe '.for_sale_price_till' do
      it 'filters properties below maximum sale price' do
        result = Pwb::Prop.for_sale_price_till(200_000_00)
        expect(result).to include(cheap_sale)
        expect(result).not_to include(expensive_sale)
      end
    end

    describe '.for_rent_price_from' do
      it 'filters properties above minimum rent price' do
        result = Pwb::Prop.for_rent_price_from(2000_00)
        expect(result).to include(expensive_rent)
        expect(result).not_to include(cheap_rent)
      end
    end

    describe '.for_rent_price_till' do
      it 'filters properties below maximum rent price' do
        result = Pwb::Prop.for_rent_price_till(2000_00)
        expect(result).to include(cheap_rent)
        expect(result).not_to include(expensive_rent)
      end
    end
  end

  describe 'room filter scopes' do
    let!(:small_prop) { create(:pwb_prop, website: website, count_bedrooms: 1, count_bathrooms: 1) }
    let!(:large_prop) { create(:pwb_prop, website: website, count_bedrooms: 4, count_bathrooms: 3) }

    describe '.count_bedrooms' do
      it 'filters properties with minimum bedrooms' do
        result = Pwb::Prop.count_bedrooms(3)
        expect(result).to include(large_prop)
        expect(result).not_to include(small_prop)
      end
    end

    describe '.count_bathrooms' do
      it 'filters properties with minimum bathrooms' do
        result = Pwb::Prop.count_bathrooms(2)
        expect(result).to include(large_prop)
        expect(result).not_to include(small_prop)
      end
    end

    describe '.bedrooms_from' do
      it 'is an alias for count_bedrooms' do
        result = Pwb::Prop.bedrooms_from(3)
        expect(result).to include(large_prop)
        expect(result).not_to include(small_prop)
      end
    end

    describe '.bathrooms_from' do
      it 'is an alias for count_bathrooms' do
        result = Pwb::Prop.bathrooms_from(2)
        expect(result).to include(large_prop)
        expect(result).not_to include(small_prop)
      end
    end
  end

  describe 'property type and state scopes' do
    let!(:apartment) { create(:pwb_prop, website: website, prop_type_key: 'propertyTypes.apartment') }
    let!(:house) { create(:pwb_prop, website: website, prop_type_key: 'propertyTypes.house') }
    let!(:new_build) { create(:pwb_prop, website: website, prop_state_key: 'propertyStates.brandNew') }

    describe '.property_type' do
      it 'filters by property type key' do
        result = Pwb::Prop.property_type('propertyTypes.apartment')
        expect(result).to include(apartment)
        expect(result).not_to include(house)
      end
    end

    describe '.property_state' do
      it 'filters by property state key' do
        result = Pwb::Prop.property_state('propertyStates.brandNew')
        expect(result).to include(new_build)
        expect(result).not_to include(apartment)
      end
    end
  end

  describe '.properties_search' do
    let!(:matching_prop) do
      create(:pwb_prop,
        website: website,
        for_sale: true,
        visible: true,
        price_sale_current_cents: 300_000_00,
        count_bedrooms: 3,
        prop_type_key: 'propertyTypes.apartment'
      )
    end

    let!(:non_matching_prop) do
      create(:pwb_prop,
        website: website,
        for_sale: true,
        visible: true,
        price_sale_current_cents: 100_000_00,
        count_bedrooms: 1
      )
    end

    it 'combines multiple search filters' do
      result = Pwb::Prop.properties_search(
        sale_or_rental: 'sale',
        for_sale_price_from: '200000',
        count_bedrooms: 2,
        currency: 'eur'
      )

      expect(result).to include(matching_prop)
      expect(result).not_to include(non_matching_prop)
    end

    it 'searches for rentals when specified' do
      rental = create(:pwb_prop, website: website, for_rent_long_term: true, visible: true)
      result = Pwb::Prop.properties_search(sale_or_rental: 'rental')

      expect(result).to include(rental)
      expect(result).not_to include(matching_prop)
    end

    it 'skips filters with value "none"' do
      result = Pwb::Prop.properties_search(
        sale_or_rental: 'sale',
        property_type: 'none'
      )

      expect(result).to include(matching_prop, non_matching_prop)
    end
  end
end
