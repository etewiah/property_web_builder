# frozen_string_literal: true

# Concern for sending ntfy notifications when listing status changes
#
# Include this in SaleListing and RentalListing models to get automatic
# push notifications when listings are published, archived, or have
# significant status changes.
#
module NtfyListingNotifications
  extend ActiveSupport::Concern

  included do
    after_commit :notify_listing_activated, if: :listing_just_activated?
    after_commit :notify_listing_archived, if: :listing_just_archived?
    after_commit :notify_listing_visible_changed, if: :listing_visibility_changed?
  end

  private

  def listing_just_activated?
    saved_change_to_active? && active?
  end

  def listing_just_archived?
    saved_change_to_archived? && archived?
  end

  def listing_visibility_changed?
    saved_change_to_visible? && !saved_change_to_active? && !saved_change_to_archived?
  end

  def notify_listing_activated
    return unless website&.ntfy_enabled?

    NtfyNotificationJob.perform_later(
      website.id,
      :listing_change,
      id,
      self.class.name,
      :published
    )
  end

  def notify_listing_archived
    return unless website&.ntfy_enabled?

    NtfyNotificationJob.perform_later(
      website.id,
      :listing_change,
      id,
      self.class.name,
      :archived
    )
  end

  def notify_listing_visible_changed
    return unless website&.ntfy_enabled?
    return unless visible? # Only notify when becoming visible

    NtfyNotificationJob.perform_later(
      website.id,
      :listing_change,
      id,
      self.class.name,
      :published
    )
  end
end
