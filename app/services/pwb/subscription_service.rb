# frozen_string_literal: true

module Pwb
  # SubscriptionService handles subscription lifecycle operations
  #
  # Usage:
  #   service = SubscriptionService.new
  #   result = service.create_trial(website: website, plan: plan)
  #   result = service.activate(subscription: subscription)
  #   result = service.change_plan(subscription: subscription, new_plan: new_plan)
  #
  class SubscriptionService
    class SubscriptionError < StandardError; end

    # Create a new trial subscription for a website
    #
    # @param website [Website] The website to subscribe
    # @param plan [Plan] The plan to subscribe to (defaults to starter)
    # @param trial_days [Integer] Override trial duration (uses plan default if nil)
    # @return [Hash] { success: true, subscription: Subscription } or { success: false, errors: [] }
    #
    def create_trial(website:, plan: nil, trial_days: nil)
      plan ||= Plan.default_plan

      return { success: false, errors: ['No plan specified and no default plan available'] } unless plan
      return { success: false, errors: ['Website already has an active subscription'] } if website.subscription&.allows_access?

      ActiveRecord::Base.transaction do
        # Remove any existing expired/canceled subscription
        website.subscription&.destroy if website.subscription&.expired? || website.subscription&.canceled?

        subscription = Subscription.create!(
          website: website,
          plan: plan,
          status: 'trialing',
          trial_ends_at: (trial_days || plan.trial_days).days.from_now,
          current_period_starts_at: Time.current,
          current_period_ends_at: (trial_days || plan.trial_days).days.from_now
        )

        subscription.events.create!(
          event_type: 'trial_started',
          metadata: { plan_id: plan.id, plan_slug: plan.slug, trial_days: trial_days || plan.trial_days }
        )

        { success: true, subscription: subscription }
      end
    rescue ActiveRecord::RecordInvalid => e
      { success: false, errors: e.record.errors.full_messages }
    rescue StandardError => e
      Rails.logger.error "[SubscriptionService] create_trial error: #{e.message}"
      { success: false, errors: [e.message] }
    end

    # Activate a subscription (convert from trial or reactivate)
    #
    # @param subscription [Subscription] The subscription to activate
    # @param external_id [String] Optional payment provider subscription ID
    # @return [Hash] { success: true, subscription: Subscription } or { success: false, errors: [] }
    #
    def activate(subscription:, external_id: nil, external_provider: nil, external_customer_id: nil)
      return { success: false, errors: ['Subscription is already active'] } if subscription.active?

      unless subscription.may_activate?
        return { success: false, errors: ["Cannot activate subscription in #{subscription.status} state"] }
      end

      ActiveRecord::Base.transaction do
        subscription.activate!

        if external_id.present?
          subscription.update!(
            external_id: external_id,
            external_provider: external_provider,
            external_customer_id: external_customer_id
          )
        end

        { success: true, subscription: subscription }
      end
    rescue AASM::InvalidTransition => e
      { success: false, errors: [e.message] }
    rescue StandardError => e
      Rails.logger.error "[SubscriptionService] activate error: #{e.message}"
      { success: false, errors: [e.message] }
    end

    # Cancel a subscription
    #
    # @param subscription [Subscription] The subscription to cancel
    # @param at_period_end [Boolean] If true, cancel at end of billing period
    # @param reason [String] Optional cancellation reason
    # @return [Hash] { success: true, subscription: Subscription } or { success: false, errors: [] }
    #
    def cancel(subscription:, at_period_end: true, reason: nil)
      return { success: false, errors: ['Subscription is already canceled'] } if subscription.canceled?

      unless subscription.may_cancel?
        return { success: false, errors: ["Cannot cancel subscription in #{subscription.status} state"] }
      end

      ActiveRecord::Base.transaction do
        if at_period_end
          subscription.update!(cancel_at_period_end: true)
          subscription.events.create!(
            event_type: 'cancellation_scheduled',
            metadata: { reason: reason, cancel_at: subscription.current_period_ends_at }
          )
        else
          subscription.cancel!
          subscription.events.create!(
            event_type: 'canceled',
            metadata: { reason: reason, immediate: true }
          )
        end

        { success: true, subscription: subscription }
      end
    rescue AASM::InvalidTransition => e
      { success: false, errors: [e.message] }
    rescue StandardError => e
      Rails.logger.error "[SubscriptionService] cancel error: #{e.message}"
      { success: false, errors: [e.message] }
    end

    # Change subscription plan
    #
    # @param subscription [Subscription] The subscription to change
    # @param new_plan [Plan] The new plan
    # @param prorate [Boolean] Whether to prorate charges (for future payment integration)
    # @return [Hash] { success: true, subscription: Subscription } or { success: false, errors: [] }
    #
    def change_plan(subscription:, new_plan:, prorate: true)
      return { success: false, errors: ['New plan is the same as current plan'] } if subscription.plan == new_plan
      return { success: false, errors: ['Cannot change plan for canceled subscription'] } if subscription.canceled?

      # Check if downgrading would violate limits
      if new_plan.property_limit.present?
        current_properties = subscription.website.realty_assets.count
        if current_properties > new_plan.property_limit
          return {
            success: false,
            errors: ["Cannot downgrade: you have #{current_properties} properties but new plan allows only #{new_plan.property_limit}"]
          }
        end
      end

      old_plan = subscription.plan

      ActiveRecord::Base.transaction do
        subscription.update!(plan: new_plan)

        subscription.events.create!(
          event_type: 'plan_changed',
          metadata: {
            old_plan_id: old_plan.id,
            old_plan_slug: old_plan.slug,
            new_plan_id: new_plan.id,
            new_plan_slug: new_plan.slug,
            prorate: prorate
          }
        )

        { success: true, subscription: subscription, old_plan: old_plan, new_plan: new_plan }
      end
    rescue StandardError => e
      Rails.logger.error "[SubscriptionService] change_plan error: #{e.message}"
      { success: false, errors: [e.message] }
    end

    # Expire trials that have ended
    # Call this from a scheduled job
    #
    # @return [Hash] { expired_count: Integer, errors: [] }
    #
    def expire_ended_trials
      expired_count = 0
      errors = []

      Subscription.trial_expired.find_each do |subscription|
        if subscription.may_expire_trial?
          subscription.expire_trial!
          expired_count += 1
        end
      rescue StandardError => e
        errors << "Subscription #{subscription.id}: #{e.message}"
      end

      { expired_count: expired_count, errors: errors }
    end

    # Process subscriptions that should be expired (canceled, past period end)
    # Call this from a scheduled job
    #
    # @return [Hash] { expired_count: Integer, errors: [] }
    #
    def expire_ended_subscriptions
      expired_count = 0
      errors = []

      # Find subscriptions scheduled for cancellation that have reached their period end
      Subscription.where(cancel_at_period_end: true)
                  .where('current_period_ends_at < ?', Time.current)
                  .find_each do |subscription|
        if subscription.may_expire?
          subscription.expire!
          expired_count += 1
        end
      rescue StandardError => e
        errors << "Subscription #{subscription.id}: #{e.message}"
      end

      { expired_count: expired_count, errors: errors }
    end

    # Get subscription status summary for a website
    #
    # @param website [Website] The website
    # @return [Hash] Status summary
    #
    def status_for(website)
      subscription = website.subscription

      return { status: 'none', has_subscription: false } unless subscription

      {
        status: subscription.status,
        has_subscription: true,
        plan_name: subscription.plan.display_name,
        plan_slug: subscription.plan.slug,
        in_good_standing: subscription.in_good_standing?,
        allows_access: subscription.allows_access?,
        trial_days_remaining: subscription.trial_days_remaining,
        trial_ending_soon: subscription.trial_ending_soon?,
        current_period_ends_at: subscription.current_period_ends_at,
        cancel_at_period_end: subscription.cancel_at_period_end,
        property_limit: subscription.plan.property_limit,
        remaining_properties: subscription.remaining_properties,
        features: subscription.plan.features
      }
    end
  end
end
