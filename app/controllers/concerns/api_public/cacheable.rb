# frozen_string_literal: true

module ApiPublic
  # Concern for adding HTTP caching to API responses
  # Supports ETag-based conditional requests and Cache-Control headers
  module Cacheable
    extend ActiveSupport::Concern

    private

    # For rarely-changing data (theme, site_details, search_config, translations)
    # Sets long cache with stale-while-revalidate for better UX
    #
    # @param max_age [ActiveSupport::Duration] Cache duration (default: 1 hour)
    # @param etag_data [Object] Data to generate ETag from
    # @return [Boolean] true if response was 304 Not Modified
    def set_long_cache(max_age: 1.hour, etag_data: nil)
      response.headers["Cache-Control"] = build_cache_control(
        max_age: max_age,
        stale_while_revalidate: max_age / 2
      )

      return false unless etag_data

      fresh_when(etag: generate_etag(etag_data), public: true)
    end

    # For moderately-changing data (properties, pages)
    # Short cache for dynamic content that still benefits from caching
    #
    # @param max_age [ActiveSupport::Duration] Cache duration (default: 5 minutes)
    # @param etag_data [Object] Data to generate ETag from
    # @return [Boolean] true if response was 304 Not Modified
    def set_short_cache(max_age: 5.minutes, etag_data: nil)
      response.headers["Cache-Control"] = build_cache_control(max_age: max_age)

      return false unless etag_data

      fresh_when(etag: generate_etag(etag_data), public: true)
    end

    # For frequently-changing or personalized data
    # Prevents any caching
    def set_no_cache
      response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"
      response.headers["Pragma"] = "no-cache"
    end

    # For private/user-specific data that can still be cached by the browser
    #
    # @param max_age [ActiveSupport::Duration] Cache duration (default: 5 minutes)
    def set_private_cache(max_age: 5.minutes)
      response.headers["Cache-Control"] = "private, max-age=#{max_age.to_i}"
    end

    # Build Cache-Control header value
    def build_cache_control(max_age:, stale_while_revalidate: nil)
      parts = ["public", "max-age=#{max_age.to_i}"]
      parts << "stale-while-revalidate=#{stale_while_revalidate.to_i}" if stale_while_revalidate
      parts.join(", ")
    end

    # Generate ETag from various data types
    def generate_etag(data)
      case data
      when Array
        Digest::MD5.hexdigest(data.map { |d| etag_value(d) }.join("-"))
      when Hash
        Digest::MD5.hexdigest(data.to_json)
      else
        etag_value(data)
      end
    end

    def etag_value(obj)
      case obj
      when ActiveRecord::Base
        "#{obj.class.name}-#{obj.id}-#{obj.updated_at.to_i}"
      when Time, DateTime, ActiveSupport::TimeWithZone
        obj.to_i.to_s
      else
        obj.to_s
      end
    end
  end
end
