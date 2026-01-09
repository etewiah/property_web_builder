# frozen_string_literal: true

module Pwb
  module Zoho
    # Sync subscription changes to Zoho CRM
    #
    # Handles:
    # - Plan selection/changes (update Lead)
    # - Subscription activation (convert Lead to Customer)
    # - Subscription cancellation (mark Lead as Lost)
    #
    # Usage:
    #   Pwb::Zoho::SyncSubscriptionJob.perform_later(subscription.id, 'activated')
    #
    class SyncSubscriptionJob < BaseJob
      VALID_EVENTS = %w[created plan_changed activated canceled expired].freeze

      def perform(subscription_id, event)
        return unless zoho_enabled?
        return unless VALID_EVENTS.include?(event.to_s)

        subscription = ::Pwb::Subscription.find_by(id: subscription_id)
        unless subscription
          Rails.logger.warn "[Zoho] Subscription #{subscription_id} not found"
          return
        end

        website = subscription.website
        user = website&.owner

        unless user
          Rails.logger.warn "[Zoho] No owner found for subscription #{subscription_id}"
          return
        end

        case event.to_s
        when 'created', 'plan_changed'
          lead_sync_service.update_lead_plan_selected(user, subscription)
        when 'activated'
          lead_sync_service.convert_lead_to_customer(user, subscription)
        when 'canceled'
          lead_sync_service.mark_lead_lost(user, 'User Canceled')
        when 'expired'
          lead_sync_service.mark_lead_lost(user, 'Trial Expired')
        end
      end
    end
  end
end
