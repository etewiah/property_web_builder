# frozen_string_literal: true

# Website::Provisionable
#
# Manages the provisioning state machine for websites.
# Tracks granular progress through the provisioning flow with guards
# to ensure each step completes successfully before moving to the next.
#
# Flow:
#   pending → owner_assigned → agency_created → links_created →
#   field_keys_created → properties_seeded → ready →
#   locked_pending_email_verification → locked_pending_registration → live
#
module Website
  module Provisionable
    extend ActiveSupport::Concern

    EMAIL_VERIFICATION_EXPIRY = ENV.fetch('EMAIL_VERIFICATION_EXPIRY_DAYS', '7').to_i.days

    included do
      include AASM

      aasm column: :provisioning_state do
        state :pending, initial: true
        state :owner_assigned
        state :agency_created
        state :links_created
        state :field_keys_created
        state :properties_seeded
        state :ready
        state :locked_pending_email_verification
        state :locked_pending_registration
        state :live
        state :failed
        state :suspended
        state :terminated

        # Step 1: Assign owner
        event :assign_owner do
          transitions from: :pending, to: :owner_assigned, guard: :has_owner?
          after do
            update!(provisioning_started_at: Time.current) if provisioning_started_at.blank?
            log_provisioning_step('owner_assigned')
          end
        end

        # Step 2: Complete agency creation
        event :complete_agency do
          transitions from: :owner_assigned, to: :agency_created, guard: :has_agency?
          after { log_provisioning_step('agency_created') }
        end

        # Step 3: Complete navigation links creation
        event :complete_links do
          transitions from: :agency_created, to: :links_created, guard: :has_links?
          after { log_provisioning_step('links_created') }
        end

        # Step 4: Complete field keys creation
        event :complete_field_keys do
          transitions from: :links_created, to: :field_keys_created, guard: :has_field_keys?
          after { log_provisioning_step('field_keys_created') }
        end

        # Step 5: Seed properties (optional - can be skipped)
        event :seed_properties do
          transitions from: :field_keys_created, to: :properties_seeded
          after { log_provisioning_step('properties_seeded') }
        end

        # Step 5b: Skip properties seeding
        event :skip_properties do
          transitions from: :field_keys_created, to: :properties_seeded
          after { log_provisioning_step('properties_skipped') }
        end

        # Step 6: Mark ready (final verification)
        event :mark_ready do
          transitions from: :properties_seeded, to: :ready, guard: :provisioning_complete?
          after do
            update!(provisioning_completed_at: Time.current)
            log_provisioning_step('ready')
          end
        end

        # Step 7: Enter locked state (awaiting email verification)
        event :enter_locked_state do
          transitions from: :ready, to: :locked_pending_email_verification, guard: :can_go_live?
          after do
            generate_email_verification_token!
            log_provisioning_step('locked_pending_email_verification')
          end
        end

        # Step 8: Verify email (user clicked verification link)
        event :verify_owner_email do
          transitions from: :locked_pending_email_verification, to: :locked_pending_registration,
                      guard: :email_verification_valid?
          after do
            update!(email_verified_at: Time.current)
            log_provisioning_step('locked_pending_registration')
          end
        end

        # Step 9: Complete registration (user created Firebase account)
        event :complete_owner_registration do
          transitions from: :locked_pending_registration, to: :live
          after { log_provisioning_step('live') }
        end

        # Direct go_live (for admin use or special cases)
        event :go_live do
          transitions from: [:ready, :locked_pending_email_verification, :locked_pending_registration],
                      to: :live, guard: :can_go_live?
          after { log_provisioning_step('live') }
        end

        # Failure handling
        event :fail_provisioning do
          transitions from: [:pending, :owner_assigned, :agency_created, :links_created,
                            :field_keys_created, :properties_seeded], to: :failed
          after do |error_message|
            update!(provisioning_error: error_message, provisioning_failed_at: Time.current)
            log_provisioning_step('failed', error: error_message)
          end
        end

        # Retry from failed state
        event :retry_provisioning do
          transitions from: :failed, to: :pending
          after do
            update!(provisioning_error: nil, provisioning_failed_at: nil)
            log_provisioning_step('retry')
          end
        end

        # Lifecycle events for live websites
        event :suspend do
          transitions from: [:ready, :live, :locked_pending_email_verification, :locked_pending_registration],
                      to: :suspended
          after { log_provisioning_step('suspended') }
        end

        event :reactivate do
          transitions from: :suspended, to: :live
          after { log_provisioning_step('reactivated') }
        end

        event :terminate do
          transitions from: [:suspended, :failed], to: :terminated
          after { log_provisioning_step('terminated') }
        end
      end
    end

    # ===================
    # Provisioning Guards
    # ===================

    def has_owner?
      user_memberships.exists?(role: 'owner', active: true)
    end

    def has_agency?
      agency.present?
    end

    def has_links?
      links.count >= 3
    end

    def has_field_keys?
      field_keys.count >= 5
    end

    def provisioning_complete?
      has_owner? && has_agency? && has_links? && has_field_keys?
    end

    def can_go_live?
      provisioning_complete? && subdomain.present?
    end

    def email_verification_valid?
      email_verification_token.present? &&
        email_verification_token_expires_at.present? &&
        email_verification_token_expires_at > Time.current
    end

    # ===================
    # Email Verification
    # ===================

    def generate_email_verification_token!
      update!(
        email_verification_token: SecureRandom.urlsafe_base64(32),
        email_verification_token_expires_at: EMAIL_VERIFICATION_EXPIRY.from_now
      )
    end

    def regenerate_email_verification_token!
      generate_email_verification_token!
    end

    def locked?
      locked_pending_email_verification? || locked_pending_registration?
    end

    def locked_mode
      return nil unless locked?
      return :pending_email_verification if locked_pending_email_verification?
      return :pending_registration if locked_pending_registration?
    end

    def email_verified?
      email_verified_at.present?
    end

    def owner
      user_memberships.find_by(role: 'owner', active: true)&.user
    end

    # ===================
    # Provisioning Status
    # ===================

    def provisioning_progress
      case provisioning_state
      when 'pending' then 0
      when 'owner_assigned' then 15
      when 'agency_created' then 30
      when 'links_created' then 45
      when 'field_keys_created' then 60
      when 'properties_seeded' then 80
      when 'ready' then 90
      when 'locked_pending_email_verification' then 95
      when 'locked_pending_registration' then 98
      when 'live' then 100
      when 'failed' then provisioning_failed_step_progress
      else 0
      end
    end

    def provisioning_status_message
      case provisioning_state
      when 'pending' then 'Waiting to start...'
      when 'owner_assigned' then 'Owner account created'
      when 'agency_created' then 'Agency information saved'
      when 'links_created' then 'Navigation links created'
      when 'field_keys_created' then 'Property fields configured'
      when 'properties_seeded' then 'Sample properties added'
      when 'ready' then 'Almost done! Finalizing...'
      when 'locked_pending_email_verification' then 'Please check your email to verify your account'
      when 'locked_pending_registration' then 'Email verified! Please create your account to continue'
      when 'live' then 'Your website is live!'
      when 'failed' then "Setup failed: #{provisioning_error}"
      when 'suspended' then 'Website suspended'
      when 'terminated' then 'Website terminated'
      else 'Unknown status'
      end
    end

    def accessible?
      live? || ready?
    end

    def provisioning?
      %w[pending owner_assigned agency_created links_created field_keys_created properties_seeded].include?(provisioning_state)
    end

    def provisioning_checklist
      {
        owner: { complete: has_owner?, required: true },
        agency: { complete: has_agency?, required: true },
        links: { complete: has_links?, count: links.count, minimum: 3, required: true },
        field_keys: { complete: has_field_keys?, count: field_keys.count, minimum: 5, required: true },
        properties: { complete: realty_assets.any?, count: realty_assets.count, required: false },
        subdomain: { complete: subdomain.present?, value: subdomain, required: true }
      }
    end

    def provisioning_missing_items
      checklist = provisioning_checklist
      missing = []
      missing << 'owner membership' unless checklist[:owner][:complete]
      missing << 'agency' unless checklist[:agency][:complete]
      missing << "links (have #{checklist[:links][:count]}, need #{checklist[:links][:minimum]})" unless checklist[:links][:complete]
      missing << "field_keys (have #{checklist[:field_keys][:count]}, need #{checklist[:field_keys][:minimum]})" unless checklist[:field_keys][:complete]
      missing << 'subdomain' unless checklist[:subdomain][:complete]
      missing
    end

    private

    def log_provisioning_step(step, error: nil)
      details = { step: step, state: provisioning_state, timestamp: Time.current.iso8601 }
      details[:error] = error if error
      Rails.logger.info("[Provisioning] Website #{id} (#{subdomain}): #{details.to_json}")
    end

    def provisioning_failed_step_progress
      return 60 if has_field_keys?
      return 45 if has_links?
      return 30 if has_agency?
      return 15 if has_owner?
      0
    end
  end
end
