# frozen_string_literal: true

# RefreshesPropertiesView triggers async refresh of the materialized view
# after property-related models are created, updated, or destroyed.
#
# Include this concern in models that affect the pwb_properties view:
#   - Pwb::RealtyAsset
#   - Pwb::SaleListing
#   - Pwb::RentalListing
#
# The refresh is debounced - multiple updates in quick succession will
# only trigger one refresh.
#
module RefreshesPropertiesView
  extend ActiveSupport::Concern

  included do
    after_commit :schedule_properties_view_refresh, on: [:create, :update, :destroy]
  end

  private

  def schedule_properties_view_refresh
    # Only schedule if job class is available
    return unless defined?(RefreshPropertiesViewJob)

    # Get website_id for cache invalidation
    website_id = try(:website_id) || try(:realty_asset)&.website_id

    # Schedule async refresh (debounced in the job)
    RefreshPropertiesViewJob.perform_later(website_id: website_id)
  rescue StandardError => e
    # Log but don't fail the transaction
    Rails.logger.warn "[RefreshesPropertiesView] Failed to schedule refresh: #{e.message}"
  end
end
