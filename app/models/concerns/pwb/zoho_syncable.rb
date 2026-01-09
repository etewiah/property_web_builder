# frozen_string_literal: true

module Pwb
  # Concern to enable automatic Zoho CRM synchronization for models
  #
  # Include this in models that should trigger Zoho sync events:
  #
  #   class User < ApplicationRecord
  #     include Pwb::ZohoSyncable
  #   end
  #
  # The concern automatically queues sync jobs when records are created/updated.
  # Sync only happens if Zoho is configured (has API credentials).
  #
  module ZohoSyncable
    extend ActiveSupport::Concern

    class_methods do
      # Track request info for Zoho (IP, UTM params, etc.)
      # Call this in controller before creating a user
      #
      # Usage:
      #   Pwb::User.with_zoho_request_info(ip: request.ip, utm_source: params[:utm_source])
      #
      def with_zoho_request_info(info)
        Thread.current[:zoho_request_info] = info
        yield
      ensure
        Thread.current[:zoho_request_info] = nil
      end
    end

    included do
      # After user signup, sync to Zoho as a Lead
      after_create_commit :schedule_zoho_signup_sync, if: :should_sync_signup_to_zoho?

      # After login, optionally track the activity
      after_update_commit :schedule_zoho_login_activity, if: :should_track_login?
    end

    private

    def should_sync_signup_to_zoho?
      # Only sync new leads (signup step 1)
      respond_to?(:onboarding_state) && onboarding_state == 'lead'
    end

    def should_track_login?
      # Track logins after first few to show engagement
      return false unless respond_to?(:sign_in_count)
      return false unless saved_change_to_sign_in_count?

      # Track 3rd, 5th, 10th login as engagement signals
      [3, 5, 10].include?(sign_in_count)
    end

    def schedule_zoho_signup_sync
      request_info = Thread.current[:zoho_request_info] || {}

      Pwb::Zoho::SyncNewSignupJob.perform_later(
        id,
        request_info.slice(:ip, :utm_source, :utm_medium, :utm_campaign).stringify_keys
      )
    end

    def schedule_zoho_login_activity
      Pwb::Zoho::SyncActivityJob.perform_later(
        id,
        'login',
        { sign_in_count: sign_in_count }
      )
    end

    # ==================
    # Public API for manual sync triggers
    # ==================

    public

    # Manually trigger Zoho lead creation (if not already synced)
    def sync_to_zoho!
      return if zoho_synced?

      Pwb::Zoho::SyncNewSignupJob.perform_later(id, {})
    end

    # Check if user has been synced to Zoho
    def zoho_synced?
      metadata&.dig('zoho_lead_id').present?
    end

    # Get Zoho lead ID if synced
    def zoho_lead_id
      metadata&.dig('zoho_lead_id')
    end

    # Check if user has been converted to a customer in Zoho
    def zoho_converted?
      metadata&.dig('zoho_contact_id').present?
    end
  end
end
