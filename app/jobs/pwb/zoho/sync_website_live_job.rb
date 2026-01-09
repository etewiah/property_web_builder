# frozen_string_literal: true

module Pwb
  module Zoho
    # Sync website going live to Zoho CRM (update Lead status)
    #
    # Triggered when website provisioning completes and email is verified
    #
    # Usage:
    #   Pwb::Zoho::SyncWebsiteLiveJob.perform_later(user.id, website.id)
    #
    class SyncWebsiteLiveJob < BaseJob
      def perform(user_id, website_id)
        return unless zoho_enabled?

        user = ::Pwb::User.find_by(id: user_id)
        website = ::Pwb::Website.find_by(id: website_id)

        unless user && website
          Rails.logger.warn "[Zoho] User #{user_id} or website #{website_id} not found"
          return
        end

        lead_sync_service.update_lead_website_live(user, website)
      end
    end
  end
end
