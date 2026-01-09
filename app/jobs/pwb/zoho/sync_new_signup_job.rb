# frozen_string_literal: true

module Pwb
  module Zoho
    # Sync a new user signup to Zoho CRM as a Lead
    #
    # Triggered when a user completes signup step 1 (email submission)
    #
    # Usage:
    #   Pwb::Zoho::SyncNewSignupJob.perform_later(user.id, { ip: '1.2.3.4', utm_source: 'google' })
    #
    class SyncNewSignupJob < BaseJob
      def perform(user_id, request_info = {})
        return unless zoho_enabled?

        user = ::Pwb::User.find_by(id: user_id)
        unless user
          Rails.logger.warn "[Zoho] User #{user_id} not found, skipping signup sync"
          return
        end

        # Skip if already synced
        if user.metadata&.dig('zoho_lead_id').present?
          Rails.logger.info "[Zoho] User #{user_id} already has lead, skipping"
          return
        end

        lead_sync_service.create_lead_from_signup(user, request_info: request_info.symbolize_keys)
      end
    end
  end
end
