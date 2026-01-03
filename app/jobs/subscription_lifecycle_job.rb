# frozen_string_literal: true

# SubscriptionLifecycleJob
#
# Handles automated subscription lifecycle events:
# - Expires ended trials
# - Expires subscriptions past their end date
# - (Future) Sends warning emails for trials ending soon
#
# Schedule: Run hourly via config/recurring.yml
#
# Usage:
#   SubscriptionLifecycleJob.perform_later
#   SubscriptionLifecycleJob.perform_now
#
class SubscriptionLifecycleJob < ApplicationJob
  queue_as :default

  # Discard job if it fails repeatedly
  discard_on StandardError do |job, error|
    Rails.logger.error "[SubscriptionLifecycleJob] Job discarded after error: #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n")
  end

  def perform
    Rails.logger.info "[SubscriptionLifecycleJob] Starting subscription lifecycle check..."

    expire_ended_trials
    expire_ended_subscriptions
    warn_about_ending_trials

    Rails.logger.info "[SubscriptionLifecycleJob] Subscription lifecycle check complete."
  end

  private

  # Expire trials that have ended without conversion to paid
  def expire_ended_trials
    result = service.expire_ended_trials

    if result[:expired_count] > 0
      Rails.logger.info "[SubscriptionLifecycleJob] Expired #{result[:expired_count]} trials"
    end

    log_errors("expire_ended_trials", result[:errors])
  end

  # Expire subscriptions that have passed their billing period end
  def expire_ended_subscriptions
    result = service.expire_ended_subscriptions

    if result[:expired_count] > 0
      Rails.logger.info "[SubscriptionLifecycleJob] Expired #{result[:expired_count]} subscriptions"
    end

    log_errors("expire_ended_subscriptions", result[:errors])
  end

  # Send warning emails for trials ending soon
  # This method is prepared for when SubscriptionMailer is implemented
  def warn_about_ending_trials
    # Only warn about trials ending in the next 3 days
    subscriptions = Pwb::Subscription.expiring_soon(3)

    subscriptions.find_each do |subscription|
      send_trial_ending_notification(subscription)
    rescue StandardError => e
      Rails.logger.error "[SubscriptionLifecycleJob] Failed to send trial warning for subscription #{subscription.id}: #{e.message}"
    end
  end

  # Send trial ending notification
  # Can be customized to use different notification channels
  def send_trial_ending_notification(subscription)
    # Skip if we've already notified recently (within last 24 hours)
    return if recently_notified?(subscription, 'trial_ending_soon')

    # Check if SubscriptionMailer exists and has the trial_ending_soon method
    if defined?(SubscriptionMailer) && SubscriptionMailer.respond_to?(:trial_ending_soon)
      SubscriptionMailer.trial_ending_soon(subscription).deliver_later
      record_notification(subscription, 'trial_ending_soon')
    else
      # Log if mailer not yet implemented
      Rails.logger.debug "[SubscriptionLifecycleJob] SubscriptionMailer not implemented, skipping trial warning email"
    end
  end

  # Check if we've sent a notification of this type recently
  def recently_notified?(subscription, notification_type)
    # Check subscription events for recent notification
    subscription.events.where(event_type: "notification_#{notification_type}")
                .where('created_at > ?', 24.hours.ago)
                .exists?
  end

  # Record that we sent a notification
  def record_notification(subscription, notification_type)
    subscription.events.create!(
      event_type: "notification_#{notification_type}",
      metadata: { sent_at: Time.current }
    )
  end

  # Log errors from service operations
  def log_errors(operation, errors)
    return if errors.blank?

    errors.each do |error|
      Rails.logger.error "[SubscriptionLifecycleJob] #{operation} error: #{error}"
    end
  end

  # Memoized subscription service
  def service
    @service ||= Pwb::SubscriptionService.new
  end
end
