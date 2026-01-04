# frozen_string_literal: true

module Pwb
  module ExternalFeed
    # Main entry point for external feed operations.
    # Handles provider instantiation, caching, and error handling.
    class Manager
      attr_reader :website, :config, :cache

      # @param website [Pwb::Website] The website to manage feeds for
      def initialize(website)
        @website = website
        @config = (website.external_feed_config || {}).deep_symbolize_keys
        @cache = CacheStore.new(website)
      end

      # Get the configured provider instance
      # @return [BaseProvider]
      # @raise [ConfigurationError] If provider is not configured or unknown
      def provider
        @provider ||= build_provider
      end

      # Check if external feeds are enabled and configured
      # @return [Boolean]
      def enabled?
        return false unless website.external_feed_enabled?
        return false if website.external_feed_provider.blank?

        begin
          provider.available?
        rescue StandardError => e
          Rails.logger.warn("[ExternalFeed::Manager] Provider availability check failed: #{e.message}")
          false
        end
      end

      # Check if external feeds are configured (regardless of availability)
      # @return [Boolean]
      def configured?
        website.external_feed_enabled? && website.external_feed_provider.present?
      end

      # Search for properties
      # @param params [Hash] Search parameters
      # @return [NormalizedSearchResult]
      def search(params = {})
        return empty_search_result(params) unless configured?

        normalized_params = normalize_search_params(params)

        cache.fetch_data(:search, normalized_params) do
          provider.search(normalized_params)
        end
      rescue Pwb::ExternalFeed::Error => e
        Rails.logger.error("[ExternalFeed::Manager] Search error: #{e.message}")
        error_search_result(params, e.message)
      rescue StandardError => e
        Rails.logger.error("[ExternalFeed::Manager] Unexpected search error: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
        error_search_result(params, "An unexpected error occurred")
      end

      # Find a single property
      # @param reference [String] Property reference
      # @param params [Hash] Additional parameters (locale, listing_type)
      # @return [NormalizedProperty, nil]
      def find(reference, params = {})
        return nil unless configured?

        cache_params = { reference: reference, **params }

        cache.fetch_data(:property, cache_params) do
          provider.find(reference, params)
        end
      rescue Pwb::ExternalFeed::PropertyNotFoundError
        nil
      rescue Pwb::ExternalFeed::Error => e
        Rails.logger.error("[ExternalFeed::Manager] Find error for #{reference}: #{e.message}")
        nil
      rescue StandardError => e
        Rails.logger.error("[ExternalFeed::Manager] Unexpected find error: #{e.message}")
        nil
      end

      # Find similar properties
      # @param property [NormalizedProperty] The property to find similar to
      # @param params [Hash] Additional parameters (limit)
      # @return [Array<NormalizedProperty>]
      def similar(property, params = {})
        return [] unless configured?
        return [] unless property

        cache_params = { reference: property.reference, **params }

        cache.fetch_data(:similar, cache_params) do
          provider.similar(property, params)
        end
      rescue Pwb::ExternalFeed::Error => e
        Rails.logger.error("[ExternalFeed::Manager] Similar error: #{e.message}")
        []
      rescue StandardError => e
        Rails.logger.error("[ExternalFeed::Manager] Unexpected similar error: #{e.message}")
        []
      end

      # Get available locations for filters
      # @param params [Hash] Filter parameters
      # @return [Array<Hash>]
      def locations(params = {})
        return [] unless configured?

        cache.fetch_data(:locations, params) do
          provider.locations(params)
        end
      rescue Pwb::ExternalFeed::Error => e
        Rails.logger.error("[ExternalFeed::Manager] Locations error: #{e.message}")
        []
      end

      # Get available property types for filters
      # @param params [Hash] Filter parameters
      # @return [Array<Hash>]
      def property_types(params = {})
        return [] unless configured?

        cache.fetch_data(:property_types, params) do
          provider.property_types(params)
        end
      rescue Pwb::ExternalFeed::Error => e
        Rails.logger.error("[ExternalFeed::Manager] Property types error: #{e.message}")
        []
      end

      # Get the search configuration for this website
      # @param listing_type [Symbol, String] The listing type (default: :sale)
      # @return [Pwb::SearchConfig]
      def search_config_for(listing_type = :sale)
        Pwb::SearchConfig.new(website, listing_type: listing_type)
      end

      # Get filter options for search forms
      # Uses SearchFilterOption model for managed options (property_types, features)
      # Falls back to provider data if no managed options exist
      # Uses SearchConfig for configurable options (bedrooms, bathrooms, price presets)
      #
      # @param params [Hash] Parameters (locale, listing_type)
      # @return [Hash] Filter options grouped by type
      def filter_options(params = {})
        listing_type = params[:listing_type] || :sale
        search_cfg = search_config_for(listing_type)

        {
          locations: locations(params),
          property_types: managed_property_types,
          features: managed_features,
          listing_types: search_cfg.listing_types_for_view,
          sort_options: search_cfg.sort_options_for_view,
          bedrooms: search_cfg.bedroom_options_for_view,
          bathrooms: search_cfg.bathroom_options_for_view,
          price_presets: search_cfg.price_presets,
          price_input_type: search_cfg.price_input_type,
          default_min_price: search_cfg.default_min_price,
          default_max_price: search_cfg.default_max_price,
          area_presets: search_cfg.area_presets,
          area_unit: search_cfg.area_unit,
          display: {
            show_results_map: search_cfg.show_map?,
            show_active_filters: search_cfg.show_active_filters?,
            show_save_search: search_cfg.show_save_search?,
            show_favorites: search_cfg.show_favorites?,
            default_sort: search_cfg.default_sort,
            default_results_per_page: search_cfg.default_results_per_page,
            results_per_page_options: search_cfg.results_per_page_options
          }
        }
      end

      # Get managed property types from SearchFilterOption model
      # Falls back to provider data if no managed options exist
      # @return [Array<Hash>]
      def managed_property_types
        managed = Pwb::SearchFilterOption.property_types
                                         .where(website: website)
                                         .visible
                                         .show_in_search
                                         .ordered
        return managed.map(&:to_option) if managed.any?

        # Fall back to provider data
        property_types
      end

      # Get managed features from SearchFilterOption model
      # Falls back to provider data if no managed options exist
      # @return [Array<Hash>]
      def managed_features
        managed = Pwb::SearchFilterOption.features
                                         .where(website: website)
                                         .visible
                                         .show_in_search
                                         .ordered
        return managed.map(&:to_option) if managed.any?

        # Fall back to provider data
        features
      end

      # Translate property type keys to external codes for API calls
      # @param keys [Array<String>] Global keys from user selection
      # @return [Array<String>] External codes for provider API
      def property_type_keys_to_external(keys)
        return keys if keys.blank?

        keys.map do |key|
          option = Pwb::SearchFilterOption.property_types
                                          .where(website: website, global_key: key)
                                          .first
          option&.external_code || key
        end.compact
      end

      # Translate feature keys to external codes/param names for API calls
      # @param keys [Array<String>] Global keys from user selection
      # @return [Array<String>] External codes for provider API
      def feature_keys_to_external(keys)
        return keys if keys.blank?

        keys.map do |key|
          option = Pwb::SearchFilterOption.features
                                          .where(website: website, global_key: key)
                                          .first
          option&.feature_param_name || option&.external_code || key
        end.compact
      end

      # Get available features for filters
      # @param params [Hash] Filter parameters
      # @return [Array<Hash>]
      def features(params = {})
        return [] unless configured?

        cache.fetch_data(:features, params) do
          provider.respond_to?(:features) ? provider.features(params) : []
        end
      rescue Pwb::ExternalFeed::Error => e
        Rails.logger.error("[ExternalFeed::Manager] Features error: #{e.message}")
        []
      end

      # Invalidate all cached data for this website
      def invalidate_cache
        cache.invalidate_all
      end

      # Get provider name
      # @return [String, nil]
      def provider_name
        website.external_feed_provider
      end

      # Get provider display name
      # @return [String]
      def provider_display_name
        return "Not Configured" unless configured?

        provider.class.display_name
      rescue StandardError
        provider_name&.titleize || "Unknown"
      end

      private

      def build_provider
        provider_name = website.external_feed_provider&.to_sym

        unless provider_name
          raise Pwb::ExternalFeed::ConfigurationError,
                "No external feed provider configured for website #{website.id}"
        end

        provider_class = Registry.find(provider_name)

        unless provider_class
          raise Pwb::ExternalFeed::ConfigurationError,
                "Unknown external feed provider: #{provider_name}. " \
                "Available: #{Registry.available_providers.join(', ')}"
        end

        provider_class.new(website, config)
      end

      def normalize_search_params(params)
        params = params.to_h.deep_symbolize_keys

        # Get search configuration for defaults
        search_cfg = search_config_for(params[:listing_type] || :sale)

        # Set defaults from SearchConfig
        params[:locale] ||= I18n.locale
        params[:listing_type] ||= search_cfg.default_listing_type
        params[:page] ||= 1
        params[:per_page] ||= search_cfg.default_results_per_page
        params[:sort] ||= search_cfg.default_sort.to_sym

        # Normalize listing type
        params[:listing_type] = params[:listing_type].to_sym if params[:listing_type].is_a?(String)

        # Normalize sort
        params[:sort] = params[:sort].to_sym if params[:sort].is_a?(String)

        # Normalize property_types to array and translate to external codes
        params[:property_types] = params[:property_types].split(",").map(&:strip) if params[:property_types].is_a?(String)
        params[:property_types] = property_type_keys_to_external(params[:property_types]) if params[:property_types].present?

        # Normalize features to array and translate to external codes
        params[:features] = params[:features].split(",").map(&:strip) if params[:features].is_a?(String)
        params[:features] = feature_keys_to_external(params[:features]) if params[:features].present?

        # Convert numeric strings
        %i[min_price max_price min_bedrooms max_bedrooms min_bathrooms max_bathrooms
           min_area max_area page per_page].each do |key|
          params[key] = params[key].to_i if params[key].present?
        end

        params.compact
      end

      def empty_search_result(params)
        NormalizedSearchResult.new(
          properties: [],
          total_count: 0,
          page: params[:page] || 1,
          per_page: params[:per_page] || 24,
          query_params: params,
          provider: provider_name&.to_sym
        )
      end

      def error_search_result(params, error_message)
        NormalizedSearchResult.new(
          properties: [],
          total_count: 0,
          page: params[:page] || 1,
          per_page: params[:per_page] || 24,
          query_params: params,
          provider: provider_name&.to_sym,
          error: error_message
        )
      end
    end
  end
end
