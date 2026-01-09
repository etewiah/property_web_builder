# frozen_string_literal: true

module Pwb
  module Zoho
    # Update Zoho leads when their trial is ending soon
    #
    # This is a scheduled job that should run daily to update leads
    # whose trial ends in 3, 2, or 1 days.
    #
    # Usage (in config/schedule.rb or Solid Queue recurring):
    #   Pwb::Zoho::TrialReminderJob.perform_later
    #
    class TrialReminderJob < BaseJob
      REMINDER_DAYS = [3, 2, 1, 0].freeze

      def perform
        return unless zoho_enabled?

        REMINDER_DAYS.each do |days|
          process_trials_ending_in(days)
        end
      end

      private

      def process_trials_ending_in(days)
        # Find subscriptions with trials ending in exactly `days` days
        target_date = Date.current + days.days

        subscriptions = ::Pwb::Subscription
          .trialing
          .where(trial_ends_at: target_date.beginning_of_day..target_date.end_of_day)
          .includes(:website)

        Rails.logger.info "[Zoho] Found #{subscriptions.count} trials ending in #{days} days"

        subscriptions.find_each do |subscription|
          user = subscription.website&.owner
          next unless user

          lead_sync_service.update_trial_ending(user, days)
        rescue Pwb::Zoho::Error => e
          Rails.logger.error "[Zoho] Failed to update trial reminder for subscription #{subscription.id}: #{e.message}"
        end
      end
    end
  end
end
