# frozen_string_literal: true

module Pwb
  # Helper methods for building SEO-friendly search URLs
  # Converts between global_keys and URL-friendly slugs
  #
  # Example URLs:
  #   /buy?type=apartment&features=pool,sea-views
  #   /rent?type=villa&bedrooms=3&features=air-conditioning
  #
  module SearchUrlHelper
    # Convert a global_key to a URL-friendly slug
    # "features.private_pool" => "private-pool"
    # "types.apartment" => "apartment"
    def feature_to_slug(global_key)
      return nil if global_key.blank?

      global_key.to_s.split('.').last.to_s.tr('_', '-')
    end

    # Convert a URL slug back to a global_key
    # "private-pool" => "features.private_pool"
    # "apartment" => "types.apartment"
    def slug_to_feature(slug, tag)
      return nil if slug.blank?

      prefix = tag_prefix(tag)
      key = "#{prefix}.#{slug.tr('-', '_')}"

      # Verify the key exists
      Pwb::FieldKey.find_by(global_key: key)&.global_key
    end

    # Get the prefix for a given tag
    def tag_prefix(tag)
      case tag.to_s
      when 'property-features' then 'features'
      when 'property-amenities' then 'amenities'
      when 'property-types' then 'types'
      when 'property-states' then 'states'
      when 'property-status' then 'status'
      when 'property-highlights' then 'highlights'
      when 'listing-origin' then 'origin'
      else tag.to_s.split('-').last
      end
    end

    # Build an SEO-friendly search URL
    #
    # @param base_path [String] The base search path (e.g., "/en/buy")
    # @param features [Array<String>] Array of feature global_keys
    # @param type [String] Property type global_key
    # @param state [String] Property state global_key
    # @param params [Hash] Additional URL parameters
    # @return [String] The constructed URL
    def search_url_with_features(base_path:, features: [], type: nil, state: nil, **params)
      url_params = params.dup

      if features.present?
        feature_slugs = features.map { |f| feature_to_slug(f) }.compact
        url_params[:features] = feature_slugs.join(',') if feature_slugs.any?
      end

      if type.present?
        url_params[:type] = feature_to_slug(type)
      end

      if state.present?
        url_params[:state] = feature_to_slug(state)
      end

      if url_params.any?
        "#{base_path}?#{url_params.to_query}"
      else
        base_path
      end
    end

    # Parse friendly URL parameters into search params
    #
    # @param params [Hash] URL parameters
    # @return [Hash] Normalized search parameters
    def parse_friendly_url_params(params)
      search_params = {}

      # Parse features (comma-separated slugs)
      if params[:features].present?
        slugs = params[:features].to_s.split(',').map(&:strip)
        feature_keys = slugs.map do |slug|
          # Try features first, then amenities
          slug_to_feature(slug, 'property-features') ||
            slug_to_feature(slug, 'property-amenities')
        end.compact

        search_params[:features] = feature_keys if feature_keys.any?
      end

      # Parse property type
      if params[:type].present?
        type_key = slug_to_feature(params[:type], 'property-types')
        search_params[:property_type] = type_key if type_key
      end

      # Parse property state
      if params[:state].present?
        state_key = slug_to_feature(params[:state], 'property-states')
        search_params[:property_state] = state_key if state_key
      end

      # Pass through standard params
      [:bedrooms, :count_bedrooms].each do |key|
        search_params[:count_bedrooms] = params[key] if params[key].present?
      end

      [:bathrooms, :count_bathrooms].each do |key|
        search_params[:count_bathrooms] = params[key] if params[key].present?
      end

      # Price params (pass through as-is)
      [:for_sale_price_from, :for_sale_price_till,
       :for_rent_price_from, :for_rent_price_till].each do |key|
        search_params[key] = params[key] if params[key].present?
      end

      # Features match mode
      if params[:features_match].present?
        search_params[:features_match] = params[:features_match]
      end

      search_params
    end

    # Generate a canonical URL for the current search
    # Useful for SEO to avoid duplicate content
    def canonical_search_url(operation_type:, search_params:, locale: I18n.locale)
      base_path = case operation_type.to_s
                  when 'for_rent', 'rent'
                    pwb.rent_path(locale: locale)
                  else
                    pwb.buy_path(locale: locale)
                  end

      canonical_params = {}

      # Add type if present
      if search_params[:property_type].present?
        canonical_params[:type] = feature_to_slug(search_params[:property_type])
      end

      # Add features if present (sorted for consistency)
      if search_params[:features].present?
        features = Array(search_params[:features]).sort
        canonical_params[:features] = features.map { |f| feature_to_slug(f) }.join(',')
      end

      # Add other params in consistent order
      [:bedrooms, :bathrooms].each do |key|
        canonical_params[key] = search_params[:"count_#{key}"] if search_params[:"count_#{key}"].present?
      end

      search_url_with_features(base_path: base_path, **canonical_params)
    end

    # Generate breadcrumb-style description of current filters
    # Useful for showing "Apartments with Pool, Sea Views" type descriptions
    def search_filter_description(search_params)
      parts = []

      if search_params[:property_type].present?
        type_label = I18n.t(search_params[:property_type], default: feature_to_slug(search_params[:property_type])&.titleize)
        parts << type_label
      end

      if search_params[:features].present?
        feature_labels = Array(search_params[:features]).map do |key|
          I18n.t(key, default: feature_to_slug(key)&.titleize)
        end
        parts << I18n.t('search.with_features', features: feature_labels.join(', '), default: "with #{feature_labels.join(', ')}")
      end

      parts.join(' ')
    end
  end
end
