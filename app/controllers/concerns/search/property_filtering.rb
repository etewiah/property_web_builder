# frozen_string_literal: true

module Search
  # Extracts property search filtering logic from SearchController
  # Handles parameter extraction, price conversion, and filter application
  module PropertyFiltering
    extend ActiveSupport::Concern

    private

    # Extract filtering parameters from request params
    # @param params [ActionController::Parameters] request params
    # @return [Hash] filtered search parameters
    def filtering_params(params)
      return [] unless params[:search]

      params[:search].slice(
        :in_locality, :in_zone,
        :for_sale_price_from, :for_sale_price_till,
        :for_rent_price_from, :for_rent_price_till,
        :property_type, :property_state,
        :count_bathrooms, :count_bedrooms
      )
    end

    # Extract feature filter parameters
    # @return [Hash] feature filter params with :features array and :features_match
    def feature_params
      return {} unless params[:search]
      params[:search].permit(:features_match, features: [])
    end

    # Apply all search filters to the properties relation
    # @param search_filtering_params [Hash] the filtering parameters
    def apply_search_filter(search_filtering_params)
      search_filtering_params.each do |key, value|
        next if value.blank? || value == "propertyTypes."

        if price_field?(key)
          value = convert_price_to_cents(value)
        end

        @properties = @properties.public_send(key, value) if value.present?
      end

      apply_feature_filters
    end

    # Check if a parameter key is a price field
    # @param key [String, Symbol] the parameter key
    # @return [Boolean] true if it's a price field
    def price_field?(key)
      %w[for_sale_price_from for_sale_price_till for_rent_price_from for_rent_price_till].include?(key.to_s)
    end

    # Convert a price value to cents using the website's currency
    # @param value [String, Integer] the price value (may include formatting)
    # @return [Integer] price in cents
    def convert_price_to_cents(value)
      currency_string = @current_website.default_currency || "usd"
      currency = Money::Currency.find(currency_string)
      # Handle both string and integer values
      numeric_value = value.is_a?(Integer) ? value : value.to_s.gsub(/\D/, "").to_i
      numeric_value * currency.subunit_to_unit
    end

    # Apply feature-based filters to the properties relation
    def apply_feature_filters
      fp = feature_params
      return if fp[:features].blank?

      feature_keys = parse_feature_keys(fp[:features])
      return if feature_keys.empty?

      @properties = if fp[:features_match] == 'any'
                      @properties.with_any_features(feature_keys)
                    else
                      @properties.with_features(feature_keys)
                    end
    end

    # Parse feature keys from various input formats
    # @param features_param [String, Array] comma-separated string or array
    # @return [Array<String>] array of feature keys
    def parse_feature_keys(features_param)
      case features_param
      when String then features_param.split(',').map(&:strip).reject(&:blank?)
      when Array then features_param.reject(&:blank?)
      else []
      end
    end
  end
end
