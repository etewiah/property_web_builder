# frozen_string_literal: true

# Property::Searchable
#
# Provides search scopes and filtering functionality for property models.
# Consolidates all search-related scopes in one place.
#
module Property
  module Searchable
    extend ActiveSupport::Concern

    included do
      scope :for_rent, -> { where('for_rent_short_term OR for_rent_long_term') }
      scope :for_sale, -> { where(for_sale: true) }
      scope :visible, -> { where(visible: true) }
      scope :in_zone, ->(key) { where(zone_key: key) }
      scope :in_locality, ->(key) { where(locality_key: key) }
      scope :property_type, ->(property_type) { where(prop_type_key: property_type) }
      scope :property_state, ->(property_state) { where(prop_state_key: property_state) }

      # Price filters
      scope :for_rent_price_from, ->(min) { where('price_rental_monthly_for_search_cents >= ?', min.to_s) }
      scope :for_rent_price_till, ->(max) { where('price_rental_monthly_for_search_cents <= ?', max.to_s) }
      scope :for_sale_price_from, ->(min) { where('price_sale_current_cents >= ?', min.to_s) }
      scope :for_sale_price_till, ->(max) { where('price_sale_current_cents <= ?', max.to_s) }

      # Room filters
      scope :count_bathrooms, ->(min) { where('count_bathrooms >= ?', min.to_s) }
      scope :count_bedrooms, ->(min) { where('count_bedrooms >= ?', min.to_s) }
      scope :bathrooms_from, ->(min) { where('count_bathrooms >= ?', min.to_s) }
      scope :bedrooms_from, ->(min) { where('count_bedrooms >= ?', min.to_s) }
    end

    class_methods do
      def properties_search(**search_filtering_params)
        currency_string = search_filtering_params[:currency] || 'usd'
        currency = Money::Currency.find(currency_string)

        search_results = if search_filtering_params[:sale_or_rental] == 'rental'
                           all.visible.for_rent
                         else
                           all.visible.for_sale
                         end

        search_filtering_params.each do |key, value|
          next if value == 'none' || key == :sale_or_rental || key == :currency

          price_fields = %i[for_sale_price_from for_sale_price_till for_rent_price_from for_rent_price_till]
          value = value.gsub(/\D/, '').to_i * currency.subunit_to_unit if price_fields.include?(key)
          search_results = search_results.public_send(key, value) if value.present?
        end

        search_results
      end
    end
  end
end
