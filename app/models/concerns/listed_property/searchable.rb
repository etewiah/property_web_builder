# frozen_string_literal: true

module ListedProperty
  # Provides search scopes and filtering functionality for ListedProperty
  # Includes visibility, operation type, price ranges, room counts, and feature filters
  module Searchable
    extend ActiveSupport::Concern

    included do
      # Default scope to eager load commonly used associations
      # Include image_attachment and blob for PropPhoto to avoid N+1 queries
      scope :with_eager_loading, -> { includes(:website, prop_photos: { image_attachment: :blob }) }

      # Basic visibility and operation type scopes
      scope :visible, -> { where(visible: true) }
      scope :for_sale, -> { where(for_sale: true) }
      scope :for_rent, -> { where(for_rent: true) }
      scope :highlighted, -> { where(highlighted: true) }

      # Property classification scopes
      # Match property type by exact key or slug suffix (e.g., 'apartment' matches 'types.apartment')
      scope :property_type, ->(property_type) {
        where('prop_type_key = ? OR prop_type_key LIKE ?', property_type, "%.#{property_type}")
      }
      scope :property_state, ->(property_state) { where(prop_state_key: property_state) }

      # Sale price range scopes (expects cents)
      scope :for_sale_price_from, ->(minimum_price) {
        where("price_sale_current_cents >= ?", minimum_price.to_s)
      }
      scope :for_sale_price_till, ->(maximum_price) {
        where("price_sale_current_cents <= ?", maximum_price.to_s)
      }

      # Rental price range scopes (expects cents)
      scope :for_rent_price_from, ->(minimum_price) {
        where("price_rental_monthly_for_search_cents >= ?", minimum_price.to_s)
      }
      scope :for_rent_price_till, ->(maximum_price) {
        where("price_rental_monthly_for_search_cents <= ?", maximum_price.to_s)
      }

      # Room count scopes (minimum counts)
      scope :count_bathrooms, ->(min_count) { where("count_bathrooms >= ?", min_count.to_s) }
      scope :count_bedrooms, ->(min_count) { where("count_bedrooms >= ?", min_count.to_s) }
      scope :bathrooms_from, ->(min_count) { where("count_bathrooms >= ?", min_count.to_s) }
      scope :bedrooms_from, ->(min_count) { where("count_bedrooms >= ?", min_count.to_s) }

      # ============================================
      # Feature Search Scopes
      # ============================================

      # Search properties that have ALL specified features (AND logic)
      # @example ListedProperty.with_features(['features.private_pool', 'features.sea_views'])
      scope :with_features, ->(feature_keys) {
        return all if feature_keys.blank?

        feature_array = Array(feature_keys).reject(&:blank?)
        return all if feature_array.empty?

        # Use subquery to avoid GROUP BY issues with SELECT *
        property_ids = PwbTenant::Feature
          .where(feature_key: feature_array)
          .group(:realty_asset_id)
          .having("COUNT(DISTINCT feature_key) = ?", feature_array.length)
          .select(:realty_asset_id)

        where(id: property_ids)
      }

      # Search properties that have ANY of the specified features (OR logic)
      # @example ListedProperty.with_any_features(['features.private_pool', 'features.sea_views'])
      scope :with_any_features, ->(feature_keys) {
        return all if feature_keys.blank?

        feature_array = Array(feature_keys).reject(&:blank?)
        return all if feature_array.empty?

        property_ids = PwbTenant::Feature
          .where(feature_key: feature_array)
          .select(:realty_asset_id)
          .distinct

        where(id: property_ids)
      }

      # Exclude properties that have specific features
      # @example ListedProperty.without_features(['features.private_pool'])
      scope :without_features, ->(feature_keys) {
        return all if feature_keys.blank?

        feature_array = Array(feature_keys).reject(&:blank?)
        return all if feature_array.empty?

        where.not(
          id: joins(:features)
            .where(pwb_features: { feature_key: feature_array })
            .select(:id)
        )
      }

      # Filter by property type key
      # @example ListedProperty.with_property_type('types.apartment')
      scope :with_property_type, ->(type_key) {
        return all if type_key.blank?
        where(prop_type_key: type_key)
      }

      # Filter by property state key
      # @example ListedProperty.with_property_state('states.new_build')
      scope :with_property_state, ->(state_key) {
        return all if state_key.blank?
        where(prop_state_key: state_key)
      }
    end

    class_methods do
      # Performs a filtered property search based on parameters
      # @param search_filtering_params [Hash] search criteria
      # @option search_filtering_params [String] :sale_or_rental "sale" or "rental"
      # @option search_filtering_params [String] :currency currency code (default: "usd")
      # @option search_filtering_params [String] :for_sale_price_from minimum sale price
      # @option search_filtering_params [String] :for_sale_price_till maximum sale price
      # @option search_filtering_params [String] :for_rent_price_from minimum rental price
      # @option search_filtering_params [String] :for_rent_price_till maximum rental price
      # @return [ActiveRecord::Relation] filtered properties
      def properties_search(**search_filtering_params)
        currency_string = search_filtering_params[:currency] || "usd"
        currency = Money::Currency.find(currency_string)

        search_results = if search_filtering_params[:sale_or_rental] == "rental"
                           all.visible.for_rent
                         else
                           all.visible.for_sale
                         end

        price_fields = %i[for_sale_price_from for_sale_price_till for_rent_price_from for_rent_price_till]

        search_filtering_params.each do |key, value|
          next if value == "none" || key == :sale_or_rental || key == :currency

          if price_fields.include?(key)
            value = value.gsub(/\D/, "").to_i * currency.subunit_to_unit
          end

          search_results = search_results.public_send(key, value) if value.present?
        end

        search_results
      end
    end
  end
end
