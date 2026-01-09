# frozen_string_literal: true

module Pwb
  module Zoho
    # Sync website creation to Zoho CRM (update existing Lead)
    #
    # Triggered when a user completes signup step 2 (website configuration)
    #
    # Usage:
    #   Pwb::Zoho::SyncWebsiteCreatedJob.perform_later(user.id, website.id)
    #
    class SyncWebsiteCreatedJob < BaseJob
      def perform(user_id, website_id)
        return unless zoho_enabled?

        user = ::Pwb::User.find_by(id: user_id)
        website = ::Pwb::Website.find_by(id: website_id)

        unless user && website
          Rails.logger.warn "[Zoho] User #{user_id} or website #{website_id} not found"
          return
        end

        # Get the plan from subscription if available
        plan = website.subscription&.plan

        lead_sync_service.update_lead_website_created(user, website, plan)
      end
    end
  end
end
