# frozen_string_literal: true

module ListedProperty
  # Handles all price-related functionality for ListedProperty
  # Including monetization, price calculations, and contextual pricing
  module Pricing
    extend ActiveSupport::Concern

    included do
      # Monetize price fields for proper currency formatting
      monetize :price_sale_current_cents,
               with_model_currency: :price_sale_current_currency,
               allow_nil: true

      monetize :price_rental_monthly_current_cents,
               with_model_currency: :price_rental_monthly_current_currency,
               allow_nil: true

      monetize :price_rental_monthly_low_season_cents,
               with_model_currency: :price_rental_monthly_current_currency,
               allow_nil: true

      monetize :price_rental_monthly_high_season_cents,
               with_model_currency: :price_rental_monthly_current_currency,
               allow_nil: true

      monetize :price_rental_monthly_for_search_cents,
               with_model_currency: :price_rental_monthly_current_currency,
               allow_nil: true

      monetize :commission_cents,
               with_model_currency: :commission_currency,
               allow_nil: true
    end

    # Standard season pricing not available in materialized view
    # These stub methods prevent errors in views that check for this column
    def price_rental_monthly_standard_season_cents
      nil
    end

    def price_rental_monthly_standard_season_cents?
      false
    end

    def price_rental_monthly_standard_season
      nil
    end

    # Returns the appropriate price based on operation type (rent vs sale)
    # @param rent_or_sale [String] "for_rent" or "for_sale"
    # @return [Money, nil] the contextual price
    def contextual_price(rent_or_sale)
      rent_or_sale ||= for_rent ? "for_rent" : "for_sale"

      if rent_or_sale == "for_rent"
        price_rental_monthly_for_search
      else
        price_sale_current
      end
    end

    # Returns formatted price with currency symbol
    # @param rent_or_sale [String] "for_rent" or "for_sale"
    # @return [String, nil] formatted price string
    def contextual_price_with_currency(rent_or_sale)
      price = contextual_price(rent_or_sale)
      return nil if price.nil? || price.zero?
      price.format(no_cents: true)
    end

    # Returns the most relevant rental price based on listing type
    # For short-term rentals, uses the lowest seasonal price
    # @return [Money, nil] the rental price
    def rental_price
      if for_rent_short_term
        lowest_short_term_price || price_rental_monthly_current
      else
        price_rental_monthly_current
      end
    end

    # Finds the lowest non-zero seasonal rental price
    # @return [Money, nil] the lowest price among seasonal options
    def lowest_short_term_price
      prices = [
        price_rental_monthly_low_season,
        price_rental_monthly_current,
        price_rental_monthly_high_season
      ].reject { |p| p.nil? || p.cents < 1 }
      prices.min
    end

    # Returns a formatted price string for display
    # Automatically detects whether to show sale or rental price
    # @return [String, nil] formatted price string with currency
    def formatted_price
      rent_or_sale = for_rent ? "for_rent" : "for_sale"
      contextual_price_with_currency(rent_or_sale)
    end
  end
end
