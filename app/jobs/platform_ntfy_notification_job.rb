# frozen_string_literal: true

# Background job for sending platform-level ntfy notifications
#
# This job wraps PlatformNtfyService calls to make them asynchronous,
# which prevents notification delivery from blocking user-facing requests.
#
# Usage:
#   PlatformNtfyNotificationJob.perform_later(:user_signup, user.id, subdomain: 'acme')
#   PlatformNtfyNotificationJob.perform_later(:provisioning_complete, website.id)
#   PlatformNtfyNotificationJob.perform_later(:subscription_activated, subscription.id)
#
class PlatformNtfyNotificationJob < ApplicationJob
  queue_as :notifications

  # Retry on transient errors
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry if ntfy is not configured
  discard_on StandardError do |job, error|
    if error.message.include?('not enabled') || error.message.include?('not configured')
      Rails.logger.debug("[PlatformNtfyNotificationJob] Discarded: #{error.message}")
      true
    else
      false
    end
  end

  # Notification types and their handlers
  NOTIFICATION_TYPES = %i[
    user_signup
    email_verified
    onboarding_complete
    provisioning_started
    provisioning_complete
    provisioning_failed
    trial_started
    subscription_activated
    trial_expired
    subscription_canceled
    payment_failed
    plan_changed
    system_alert
    daily_summary
  ].freeze

  def perform(notification_type, *args)
    notification_type = notification_type.to_sym

    unless NOTIFICATION_TYPES.include?(notification_type)
      Rails.logger.warn("[PlatformNtfyNotificationJob] Unknown type: #{notification_type}")
      return
    end

    send("handle_#{notification_type}", *args)
  end

  private

  # ===================
  # User Lifecycle
  # ===================

  def handle_user_signup(user_id, options = {})
    user = Pwb::User.find_by(id: user_id)
    return unless user

    PlatformNtfyService.notify_user_signup(
      user,
      reserved_subdomain: options[:subdomain] || options['subdomain']
    )
  end

  def handle_email_verified(user_id, _options = {})
    user = Pwb::User.find_by(id: user_id)
    return unless user

    PlatformNtfyService.notify_email_verified(user)
  end

  def handle_onboarding_complete(user_id, website_id, _options = {})
    user = Pwb::User.find_by(id: user_id)
    website = Pwb::Website.unscoped.find_by(id: website_id)
    return unless user && website

    PlatformNtfyService.notify_onboarding_complete(user, website)
  end

  # ===================
  # Website Provisioning
  # ===================

  def handle_provisioning_started(website_id, _options = {})
    website = Pwb::Website.unscoped.find_by(id: website_id)
    return unless website

    PlatformNtfyService.notify_provisioning_started(website)
  end

  def handle_provisioning_complete(website_id, _options = {})
    website = Pwb::Website.unscoped.find_by(id: website_id)
    return unless website

    PlatformNtfyService.notify_provisioning_complete(website)
  end

  def handle_provisioning_failed(website_id, options = {})
    website = Pwb::Website.unscoped.find_by(id: website_id)
    return unless website

    error = options[:error] || options['error'] || 'Unknown error'
    PlatformNtfyService.notify_provisioning_failed(website, error)
  end

  # ===================
  # Subscription Events
  # ===================

  def handle_trial_started(subscription_id, _options = {})
    subscription = Pwb::Subscription.find_by(id: subscription_id)
    return unless subscription

    PlatformNtfyService.notify_trial_started(subscription)
  end

  def handle_subscription_activated(subscription_id, _options = {})
    subscription = Pwb::Subscription.find_by(id: subscription_id)
    return unless subscription

    PlatformNtfyService.notify_subscription_activated(subscription)
  end

  def handle_trial_expired(subscription_id, _options = {})
    subscription = Pwb::Subscription.find_by(id: subscription_id)
    return unless subscription

    PlatformNtfyService.notify_trial_expired(subscription)
  end

  def handle_subscription_canceled(subscription_id, options = {})
    subscription = Pwb::Subscription.find_by(id: subscription_id)
    return unless subscription

    reason = options[:reason] || options['reason']
    PlatformNtfyService.notify_subscription_canceled(subscription, reason: reason)
  end

  def handle_payment_failed(subscription_id, options = {})
    subscription = Pwb::Subscription.find_by(id: subscription_id)
    return unless subscription

    error_details = options[:error_details] || options['error_details']
    PlatformNtfyService.notify_payment_failed(subscription, error_details: error_details)
  end

  def handle_plan_changed(subscription_id, options = {})
    subscription = Pwb::Subscription.find_by(id: subscription_id)
    return unless subscription

    old_plan_id = options[:old_plan_id] || options['old_plan_id']
    new_plan_id = options[:new_plan_id] || options['new_plan_id']

    old_plan = Pwb::Plan.find_by(id: old_plan_id)
    new_plan = Pwb::Plan.find_by(id: new_plan_id)
    return unless old_plan && new_plan

    PlatformNtfyService.notify_plan_changed(subscription, old_plan, new_plan)
  end

  # ===================
  # System Events
  # ===================

  def handle_system_alert(title, options = {})
    message = options[:message] || options['message'] || ''
    priority = options[:priority] || options['priority'] || PlatformNtfyService::PRIORITY_URGENT

    PlatformNtfyService.notify_system_alert(title, message, priority: priority)
  end

  def handle_daily_summary(metrics, _options = {})
    # Convert string keys to symbols if needed
    metrics = metrics.transform_keys(&:to_sym) if metrics.is_a?(Hash)
    PlatformNtfyService.notify_daily_summary(metrics)
  end
end
