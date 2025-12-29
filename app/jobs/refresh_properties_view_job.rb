# frozen_string_literal: true

# RefreshPropertiesViewJob refreshes the materialized view asynchronously
#
# The pwb_properties materialized view denormalizes property data for fast reads.
# This job should be enqueued after property updates to keep the view current.
#
# MULTI-TENANCY:
#   This is a GLOBAL operation that refreshes data for ALL tenants.
#   The materialized view includes website_id for tenant filtering at query time.
#   No ActsAsTenant context is needed because:
#   - The view refresh operates on all data
#   - Individual tenant queries filter by website_id automatically
#   - Cache invalidation uses website_id parameter for tenant-specific caches
#
# Usage:
#   RefreshPropertiesViewJob.perform_later
#   RefreshPropertiesViewJob.perform_later(website_id: 123) # For cache invalidation
#
# Debouncing:
#   Multiple calls within a short period are deduplicated using a Redis lock
#   to prevent excessive refreshes during bulk updates.
#
class RefreshPropertiesViewJob < ApplicationJob
  queue_as :default

  # Debounce window - ignore duplicate refresh requests within this period
  DEBOUNCE_WINDOW = 5.seconds

  def perform(website_id: nil)
    # Skip if another refresh happened recently (debounce)
    return if recently_refreshed?

    # Record refresh time
    mark_refreshed

    # Refresh the materialized view concurrently (allows reads during refresh)
    Rails.logger.info "[RefreshPropertiesViewJob] Starting materialized view refresh"

    start_time = Time.current
    Pwb::ListedProperty.refresh(concurrently: true)
    duration = Time.current - start_time

    Rails.logger.info "[RefreshPropertiesViewJob] View refresh completed in #{duration.round(2)}s"

    # Invalidate relevant caches if website_id provided
    if website_id
      CacheService.invalidate_property_caches(website_id)
    end
  rescue StandardError => e
    Rails.logger.error "[RefreshPropertiesViewJob] Error refreshing view: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")

    # Re-raise to allow retry mechanism
    raise
  end

  private

  def recently_refreshed?
    return false unless Rails.cache.respond_to?(:read)

    Rails.cache.read(debounce_key).present?
  end

  def mark_refreshed
    return unless Rails.cache.respond_to?(:write)

    Rails.cache.write(debounce_key, Time.current.to_i, expires_in: DEBOUNCE_WINDOW)
  end

  def debounce_key
    "pwb:properties_view_refresh_lock"
  end
end
