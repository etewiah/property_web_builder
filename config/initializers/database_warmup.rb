# frozen_string_literal: true

# Database Connection Warm-up
#
# Pre-warms the database connection pool on application boot to avoid
# cold-start latency on the first request. This moves the PostgreSQL
# type mapping and connection setup overhead from the first request
# to the boot phase.
#
# This is especially helpful in production where the first request
# might otherwise take 50-100ms longer due to connection setup.

Rails.application.config.after_initialize do
  if Rails.env.production? || ENV["WARMUP_DB"] == "true"
    Rails.logger.info "[Database Warmup] Pre-warming database connection..."

    begin
      # Execute a simple query to establish the connection and
      # trigger PostgreSQL type mapping
      ActiveRecord::Base.connection.execute("SELECT 1")

      # Optionally preload the first website to populate caches
      if defined?(Pwb::Website) && Pwb::Website.table_exists?
        Pwb::Website.first
      end

      Rails.logger.info "[Database Warmup] Connection warmed up successfully"
    rescue StandardError => e
      Rails.logger.warn "[Database Warmup] Failed to warm up: #{e.message}"
    end
  end
end
