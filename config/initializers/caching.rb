# frozen_string_literal: true

# Caching Configuration
#
# This initializer configures the Rails cache store based on environment.
# Production uses Redis for distributed caching across multiple servers.
# Development uses memory store for simplicity.
#
# Environment variables:
#   REDIS_URL - Redis connection URL (defaults to redis://localhost:6379/1)
#   REDIS_CACHE_URL - Separate Redis URL for caching (optional, uses REDIS_URL if not set)
#
# Cache key conventions:
#   - All keys are prefixed with "pwb:" to namespace the app
#   - Tenant-scoped keys include website_id: "pwb:w{website_id}:..."
#   - Locale-aware keys include locale: "pwb:w{website_id}:l{locale}:..."
#

Rails.application.configure do
  if Rails.env.production?
    redis_url = ENV.fetch("REDIS_CACHE_URL") { ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }

    config.cache_store = :redis_cache_store, {
      url: redis_url,
      namespace: "pwb",
      # Connection pool settings for multi-threaded servers (Puma)
      pool_size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i,
      pool_timeout: 5,
      # Reconnect on failure
      reconnect_attempts: 3,
      # Compress values larger than 1KB
      compress: true,
      compress_threshold: 1.kilobyte,
      # Error handling - log and continue (don't crash on Redis issues)
      error_handler: ->(method:, returning:, exception:) {
        Rails.logger.warn("Redis cache error: #{method} - #{exception.class}: #{exception.message}")
        Sentry.capture_exception(exception) if defined?(Sentry)
      },
      # Expiry defaults
      expires_in: 1.hour
    }
  elsif Rails.env.test?
    config.cache_store = :null_store
  else
    # Development: use memory store (or Redis if REDIS_URL is set)
    if ENV["REDIS_URL"].present?
      config.cache_store = :redis_cache_store, {
        url: ENV["REDIS_URL"],
        namespace: "pwb_dev",
        expires_in: 5.minutes
      }
    else
      config.cache_store = :memory_store, { size: 64.megabytes }
    end
  end
end
