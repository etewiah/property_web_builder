# frozen_string_literal: true

# Background job for sending ntfy notifications asynchronously
#
# This ensures that notification delivery doesn't block web requests.
# Notifications are sent in the background and failures are logged
# without affecting the main application flow.
#
# Usage:
#   NtfyNotificationJob.perform_later(website_id, :inquiry, message_id)
#   NtfyNotificationJob.perform_later(website_id, :listing_change, listing_id, 'SaleListing', :published)
#   NtfyNotificationJob.perform_later(website_id, :security, nil, nil, 'login_failed', { email: 'user@example.com' })
#
class NtfyNotificationJob < ActiveJob::Base
  queue_as :notifications

  # Retry failed jobs with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry if ntfy is disabled or record not found
  discard_on ActiveRecord::RecordNotFound

  def perform(website_id, notification_type, record_id = nil, record_class = nil, action = nil, details = nil)
    website = Pwb::Website.find(website_id)
    return unless website.ntfy_enabled?

    case notification_type.to_sym
    when :inquiry
      handle_inquiry(website, record_id)
    when :listing_change
      handle_listing_change(website, record_id, record_class, action)
    when :user_event
      handle_user_event(website, record_id, action)
    when :security
      handle_security_event(website, action, details)
    when :admin
      handle_admin_notification(website, action, details)
    else
      Rails.logger.warn("[NtfyNotificationJob] Unknown notification type: #{notification_type}")
    end
  end

  private

  def handle_inquiry(website, message_id)
    message = Pwb::Message.find(message_id)
    NtfyService.notify_inquiry(website, message)
  end

  def handle_listing_change(website, listing_id, listing_class, action)
    listing_klass = listing_class.constantize
    listing = listing_klass.find(listing_id)
    NtfyService.notify_listing_change(website, listing, action.to_sym)
  end

  def handle_user_event(website, user_id, event)
    user = Pwb::User.find(user_id)
    NtfyService.notify_user_event(website, user, event.to_sym)
  end

  def handle_security_event(website, event_type, details)
    NtfyService.notify_security_event(website, event_type, details&.symbolize_keys || {})
  end

  def handle_admin_notification(website, title, details)
    message = details&.dig(:message) || details&.dig('message')
    options = {
      priority: details&.dig(:priority) || details&.dig('priority'),
      tags: details&.dig(:tags) || details&.dig('tags'),
      click_url: details&.dig(:click_url) || details&.dig('click_url')
    }.compact

    NtfyService.notify_admin(website, title, message, options)
  end
end
