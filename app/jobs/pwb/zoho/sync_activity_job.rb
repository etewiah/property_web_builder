# frozen_string_literal: true

module Pwb
  module Zoho
    # Sync user activity to Zoho CRM as notes + engagement score
    #
    # Tracks important user actions that indicate engagement:
    # - Adding properties
    # - Customizing website (logo, theme, pages)
    # - Receiving inquiries
    # - Adding team members
    #
    # Usage:
    #   Pwb::Zoho::SyncActivityJob.perform_later(user.id, 'property_added', { title: 'Beach House', reference: 'BH-001' })
    #
    class SyncActivityJob < BaseJob
      def perform(user_id, activity_type, details = {})
        return unless zoho_enabled?

        user = ::Pwb::User.find_by(id: user_id)
        unless user
          Rails.logger.warn "[Zoho] User #{user_id} not found for activity sync"
          return
        end

        # Skip if user hasn't been synced to Zoho yet
        unless user.metadata&.dig('zoho_lead_id').present?
          Rails.logger.debug "[Zoho] User #{user_id} has no Zoho lead, skipping activity"
          return
        end

        lead_sync_service.log_activity(user, activity_type, details.symbolize_keys)
      end
    end
  end
end
