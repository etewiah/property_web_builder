# frozen_string_literal: true

module Pwb
  module ExternalFeed
    # Cache wrapper for external feed data.
    # Provides consistent caching with website-scoped keys and configurable TTLs.
    class CacheStore
      attr_reader :website, :provider_name, :config

      # Default TTLs in seconds
      DEFAULT_TTLS = {
        search: 3600,        # 1 hour
        property: 86400,     # 24 hours
        similar: 21600,      # 6 hours
        locations: 604800,   # 1 week
        property_types: 604800 # 1 week
      }.freeze

      # @param website [Pwb::Website] The website for cache scoping
      def initialize(website)
        @website = website
        @provider_name = website.external_feed_provider
        @config = website.external_feed_config&.deep_symbolize_keys || {}
      end

      # Fetch from cache or execute block
      # @param operation [Symbol] The operation type (:search, :property, etc.)
      # @param params [Hash] Parameters to include in cache key
      # @param ttl [Integer, nil] Optional TTL override in seconds
      # @yield Block to execute if cache miss
      # @return [Object] Cached or fresh data
      def fetch(operation, params, ttl: nil, &block)
        key = cache_key(operation, params)
        ttl ||= ttl_for(operation)

        Rails.cache.fetch(key, expires_in: ttl.seconds) do
          result = block.call

          # Wrap in cache metadata
          {
            data: result,
            cached_at: Time.current.iso8601,
            provider: provider_name,
            operation: operation
          }
        end
      end

      # Get cached data without metadata wrapper
      # @param operation [Symbol] The operation type
      # @param params [Hash] Parameters
      # @param ttl [Integer, nil] Optional TTL override
      # @yield Block to execute if cache miss
      # @return [Object] The actual data (unwrapped)
      def fetch_data(operation, params, ttl: nil, &block)
        result = fetch(operation, params, ttl: ttl, &block)
        result.is_a?(Hash) && result.key?(:data) ? result[:data] : result
      end

      # Read from cache without executing block
      # @param operation [Symbol] The operation type
      # @param params [Hash] Parameters
      # @return [Object, nil] Cached data or nil
      def read(operation, params)
        key = cache_key(operation, params)
        Rails.cache.read(key)
      end

      # Write to cache
      # @param operation [Symbol] The operation type
      # @param params [Hash] Parameters
      # @param data [Object] Data to cache
      # @param ttl [Integer, nil] Optional TTL override
      def write(operation, params, data, ttl: nil)
        key = cache_key(operation, params)
        ttl ||= ttl_for(operation)

        Rails.cache.write(key, {
          data: data,
          cached_at: Time.current.iso8601,
          provider: provider_name
        }, expires_in: ttl.seconds)
      end

      # Invalidate specific cache entry
      # @param operation [Symbol] The operation type
      # @param params [Hash] Parameters
      def invalidate(operation, params)
        key = cache_key(operation, params)
        Rails.cache.delete(key)
      end

      # Invalidate all cache entries for an operation
      # @param operation [Symbol] The operation type
      def invalidate_operation(operation)
        pattern = cache_key_pattern(operation)
        delete_matched(pattern)
      end

      # Invalidate all cache entries for this website's external feed
      def invalidate_all
        pattern = "pwb:external_feed:#{website.id}:*"
        delete_matched(pattern)
      end

      # Check if data is cached
      # @param operation [Symbol] The operation type
      # @param params [Hash] Parameters
      # @return [Boolean]
      def cached?(operation, params)
        key = cache_key(operation, params)
        Rails.cache.exist?(key)
      end

      # Get cache key for debugging
      # @param operation [Symbol] The operation type
      # @param params [Hash] Parameters
      # @return [String]
      def cache_key(operation, params)
        params_hash = Digest::MD5.hexdigest(normalize_params(params).to_json)
        "pwb:external_feed:#{website.id}:#{provider_name}:#{operation}:#{params_hash}"
      end

      private

      # Get TTL for an operation from config or defaults
      # @param operation [Symbol] The operation type
      # @return [Integer] TTL in seconds
      def ttl_for(operation)
        config_key = :"cache_ttl_#{operation}"
        config[config_key]&.to_i || DEFAULT_TTLS[operation] || DEFAULT_TTLS[:search]
      end

      # Build cache key pattern for matching
      # @param operation [Symbol] The operation type
      # @return [String]
      def cache_key_pattern(operation)
        "pwb:external_feed:#{website.id}:#{provider_name}:#{operation}:*"
      end

      # Delete all keys matching pattern
      # @param pattern [String] The pattern to match
      def delete_matched(pattern)
        # Use delete_matched if available (Redis), otherwise skip
        if Rails.cache.respond_to?(:delete_matched)
          Rails.cache.delete_matched(pattern)
        else
          Rails.logger.warn("[ExternalFeed::CacheStore] Cache store doesn't support delete_matched")
        end
      end

      # Normalize params for consistent cache keys
      # @param params [Hash] Raw parameters
      # @return [Hash] Sorted, normalized parameters
      def normalize_params(params)
        return {} if params.blank?

        params
          .deep_symbolize_keys
          .compact
          .reject { |_, v| v.respond_to?(:empty?) && v.empty? }
          .sort
          .to_h
      end
    end
  end
end
