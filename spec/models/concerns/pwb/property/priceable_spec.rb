# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::PropertyPriceable, type: :model do
  let(:website) { create(:pwb_website) }
  let(:prop) { create(:pwb_prop, website: website, currency: 'EUR') }

  around do |example|
    ActsAsTenant.with_tenant(website) do
      example.run
    end
  end

  describe 'monetization' do
    it 'monetizes price_sale_current' do
      prop.price_sale_current_cents = 250_000_00
      expect(prop.price_sale_current).to be_a(Money)
      expect(prop.price_sale_current.cents).to eq(250_000_00)
    end

    it 'monetizes price_rental_monthly_current' do
      prop.price_rental_monthly_current_cents = 150_000
      expect(prop.price_rental_monthly_current).to be_a(Money)
      expect(prop.price_rental_monthly_current.cents).to eq(150_000)
    end
  end

  describe '#contextual_price' do
    before do
      prop.price_sale_current_cents = 500_000_00
      prop.price_rental_monthly_for_search_cents = 200_000
    end

    it 'returns sale price for for_sale' do
      expect(prop.contextual_price('for_sale').cents).to eq(500_000_00)
    end

    it 'returns rental price for for_rent' do
      expect(prop.contextual_price('for_rent').cents).to eq(200_000)
    end

    it 'defaults to sale price based on property availability' do
      prop.for_sale = true
      prop.for_rent_long_term = false
      prop.for_rent_short_term = false
      expect(prop.contextual_price(nil).cents).to eq(500_000_00)
    end

    it 'defaults to rental price when property is for rent' do
      prop.for_sale = false
      prop.for_rent_long_term = true
      expect(prop.contextual_price(nil).cents).to eq(200_000)
    end
  end

  describe '#contextual_price_with_currency' do
    it 'formats price with currency' do
      prop.price_sale_current_cents = 500_000_00
      result = prop.contextual_price_with_currency('for_sale')
      expect(result).to include('500,000')
    end

    it 'returns nil for zero price' do
      prop.price_sale_current_cents = 0
      expect(prop.contextual_price_with_currency('for_sale')).to be_nil
    end
  end

  describe '#rental_price' do
    context 'for short term rentals' do
      before { prop.for_rent_short_term = true }

      it 'returns lowest short term price when available' do
        prop.price_rental_monthly_low_season_cents = 100_000
        prop.price_rental_monthly_standard_season_cents = 150_000
        prop.price_rental_monthly_high_season_cents = 200_000

        expect(prop.rental_price.cents).to eq(100_000)
      end

      it 'falls back to current price when no seasonal prices' do
        prop.price_rental_monthly_low_season_cents = 0
        prop.price_rental_monthly_standard_season_cents = 0
        prop.price_rental_monthly_high_season_cents = 0
        prop.price_rental_monthly_current_cents = 150_000

        expect(prop.rental_price.cents).to eq(150_000)
      end
    end

    context 'for long term rentals' do
      before do
        prop.for_rent_short_term = false
        prop.for_rent_long_term = true
      end

      it 'returns current rental price' do
        prop.price_rental_monthly_current_cents = 180_000
        expect(prop.rental_price.cents).to eq(180_000)
      end
    end

    it 'returns nil when no rental price is set' do
      prop.for_rent_short_term = false
      prop.price_rental_monthly_current_cents = 0
      expect(prop.rental_price).to be_nil
    end
  end

  describe '#lowest_short_term_price' do
    it 'returns the minimum of seasonal prices' do
      prop.price_rental_monthly_low_season_cents = 150_000
      prop.price_rental_monthly_standard_season_cents = 200_000
      prop.price_rental_monthly_high_season_cents = 250_000

      expect(prop.lowest_short_term_price.cents).to eq(150_000)
    end

    it 'excludes zero prices' do
      prop.price_rental_monthly_low_season_cents = 0
      prop.price_rental_monthly_standard_season_cents = 200_000
      prop.price_rental_monthly_high_season_cents = 250_000

      expect(prop.lowest_short_term_price.cents).to eq(200_000)
    end

    it 'returns nil when all prices are zero' do
      prop.price_rental_monthly_low_season_cents = 0
      prop.price_rental_monthly_standard_season_cents = 0
      prop.price_rental_monthly_high_season_cents = 0

      expect(prop.lowest_short_term_price).to be_nil
    end
  end

  describe 'before_save callback' do
    it 'sets rental search price from rental_price' do
      prop.for_rent_long_term = true
      prop.price_rental_monthly_current_cents = 150_000
      prop.save!

      expect(prop.price_rental_monthly_for_search_cents).to eq(150_000)
    end
  end
end
