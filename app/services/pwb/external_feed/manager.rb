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
      rescue Error => e
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
      rescue PropertyNotFoundError
        nil
      rescue Error => e
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
      rescue Error => e
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
      rescue Error => e
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
      rescue Error => e
        Rails.logger.error("[ExternalFeed::Manager] Property types error: #{e.message}")
        []
      end

      # Get filter options for search forms
      # @param params [Hash] Parameters (locale)
      # @return [Hash] Filter options grouped by type
      def filter_options(params = {})
        {
          locations: locations(params),
          property_types: property_types(params),
          listing_types: [
            { value: "sale", label: I18n.t("external_feed.listing_types.sale", default: "For Sale") },
            { value: "rental", label: I18n.t("external_feed.listing_types.rental", default: "For Rent") }
          ],
          sort_options: [
            { value: "price_asc", label: I18n.t("external_feed.sort.price_asc", default: "Price (Low to High)") },
            { value: "price_desc", label: I18n.t("external_feed.sort.price_desc", default: "Price (High to Low)") },
            { value: "newest", label: I18n.t("external_feed.sort.newest", default: "Newest First") },
            { value: "updated", label: I18n.t("external_feed.sort.updated", default: "Recently Updated") }
          ],
          bedrooms: (1..6).map { |n| { value: n.to_s, label: "#{n}+" } },
          bathrooms: (1..4).map { |n| { value: n.to_s, label: "#{n}+" } }
        }
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
          raise ConfigurationError, "No external feed provider configured for website #{website.id}"
        end

        provider_class = Registry.find(provider_name)

        unless provider_class
          raise ConfigurationError, "Unknown external feed provider: #{provider_name}. " \
                                    "Available: #{Registry.available_providers.join(', ')}"
        end

        provider_class.new(website, config)
      end

      def normalize_search_params(params)
        params = params.to_h.deep_symbolize_keys

        # Set defaults
        params[:locale] ||= I18n.locale
        params[:listing_type] ||= :sale
        params[:page] ||= 1
        params[:per_page] ||= config[:results_per_page] || 24

        # Normalize listing type
        params[:listing_type] = params[:listing_type].to_sym if params[:listing_type].is_a?(String)

        # Normalize sort
        params[:sort] = params[:sort].to_sym if params[:sort].is_a?(String)

        # Normalize property_types to array
        if params[:property_types].is_a?(String)
          params[:property_types] = params[:property_types].split(",").map(&:strip)
        end

        # Normalize features to array
        if params[:features].is_a?(String)
          params[:features] = params[:features].split(",").map(&:strip)
        end

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
