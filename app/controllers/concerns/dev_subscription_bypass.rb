# frozen_string_literal: true

# DevSubscriptionBypass
# Allows setting a subscription plan via environment variable in development.
#
# Usage:
#   DEV_SUBSCRIPTION_PLAN=enterprise rails s
#   DEV_SUBSCRIPTION_PLAN=professional rails s
#   DEV_SUBSCRIPTION_PLAN=starter rails s
#
# This will automatically create/update a subscription for the current website
# with the specified plan, set to 'active' status.
#
# SECURITY: This bypass is ONLY allowed in development and e2e environments.
# It will be ignored in production, staging, and any other environment.
#
module DevSubscriptionBypass
  extend ActiveSupport::Concern

  ALLOWED_ENVIRONMENTS = %w[development e2e test].freeze

  included do
    before_action :apply_dev_subscription_bypass
  end

  private

  def dev_subscription_bypass_enabled?
    return false unless ALLOWED_ENVIRONMENTS.include?(Rails.env)

    ENV['DEV_SUBSCRIPTION_PLAN'].present?
  end

  def apply_dev_subscription_bypass
    return unless dev_subscription_bypass_enabled?

    website = respond_to?(:current_website) ? current_website : Pwb::Current.website
    return unless website

    ensure_website_has_plan(website, ENV['DEV_SUBSCRIPTION_PLAN'])
  end

  def ensure_website_has_plan(website, plan_slug)
    # Find the requested plan
    plan = Pwb::Plan.find_by(slug: plan_slug) || Pwb::Plan.find_by(name: plan_slug)

    unless plan
      Rails.logger.warn "[DevSubscriptionBypass] Plan '#{plan_slug}' not found. " \
                        "Available plans: #{Pwb::Plan.pluck(:slug).join(', ')}"
      return
    end

    # Check if website already has this plan with active status
    existing_subscription = website.subscription
    if existing_subscription&.plan_id == plan.id && existing_subscription.active?
      return # Already set up correctly
    end

    # Create or update subscription
    subscription = existing_subscription || website.build_subscription
    subscription.plan = plan
    subscription.status = 'active'
    subscription.current_period_starts_at = Time.current
    subscription.current_period_ends_at = 1.year.from_now
    subscription.trial_ends_at = nil # Not in trial

    if subscription.save
      Rails.logger.info "[DevSubscriptionBypass] Set website '#{website.subdomain}' to plan '#{plan.display_name}'"
    else
      Rails.logger.warn "[DevSubscriptionBypass] Failed to set plan: #{subscription.errors.full_messages.join(', ')}"
    end
  rescue StandardError => e
    Rails.logger.warn "[DevSubscriptionBypass] Error setting subscription: #{e.message}"
  end
end
