# frozen_string_literal: true

# Property::Priceable
#
# Provides price-related functionality for property models.
# Handles sale prices, rental prices, and price formatting.
#
module Property
  module Priceable
    extend ActiveSupport::Concern

    included do
      monetize :price_sale_current_cents, with_model_currency: :currency, allow_nil: true
      monetize :price_sale_original_cents, with_model_currency: :currency
      monetize :price_rental_monthly_current_cents, with_model_currency: :currency
      monetize :price_rental_monthly_original_cents, with_model_currency: :currency
      monetize :price_rental_monthly_low_season_cents, with_model_currency: :currency
      monetize :price_rental_monthly_high_season_cents, with_model_currency: :currency
      monetize :price_rental_monthly_standard_season_cents, with_model_currency: :currency
      monetize :price_rental_monthly_for_search_cents, with_model_currency: :currency
      monetize :commission_cents, with_model_currency: :currency
      monetize :service_charge_yearly_cents, with_model_currency: :currency

      before_save :set_rental_search_price
    end

    def contextual_price(rent_or_sale)
      rent_or_sale ||= for_rent ? 'for_rent' : 'for_sale'
      if rent_or_sale == 'for_rent'
        price_rental_monthly_for_search
      else
        price_sale_current
      end
    end

    def contextual_price_with_currency(rent_or_sale)
      price = contextual_price(rent_or_sale)
      price.zero? ? nil : price.format(no_cents: true)
    end

    def rental_price
      rental_price = lowest_short_term_price || 0 if for_rent_short_term
      rental_price = price_rental_monthly_current || 0 unless rental_price&.positive?
      rental_price&.positive? ? rental_price : nil
    end

    def lowest_short_term_price
      prices_array = [
        price_rental_monthly_low_season,
        price_rental_monthly_standard_season,
        price_rental_monthly_high_season
      ]
      prices_array.reject! { |a| a.cents < 1 }
      prices_array.min
    end

    private

    def set_rental_search_price
      self.price_rental_monthly_for_search = rental_price
    end
  end
end
