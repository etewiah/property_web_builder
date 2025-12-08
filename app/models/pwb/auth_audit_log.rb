# frozen_string_literal: true

module Pwb
  # AuthAuditLog records all authentication-related events for security monitoring.
  #
  # Events logged include:
  # - login_success: Successful email/password login
  # - login_failure: Failed login attempt
  # - logout: User signed out
  # - oauth_success: Successful OAuth authentication
  # - oauth_failure: Failed OAuth authentication
  # - password_reset_request: Password reset email requested
  # - password_reset_success: Password successfully reset
  # - account_locked: Account locked after failed attempts
  # - account_unlocked: Account unlocked (via email or time)
  # - session_timeout: Session expired due to inactivity
  # - registration: New user registration
  #
  class AuthAuditLog < ApplicationRecord
    self.table_name = 'pwb_auth_audit_logs'

    belongs_to :user, class_name: 'Pwb::User', optional: true
    belongs_to :website, class_name: 'Pwb::Website', optional: true

    # Event types
    EVENT_TYPES = %w[
      login_success
      login_failure
      logout
      oauth_success
      oauth_failure
      password_reset_request
      password_reset_success
      account_locked
      account_unlocked
      session_timeout
      registration
    ].freeze

    validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }

    # Send ntfy notifications for security-relevant events
    after_commit :send_security_notification, on: :create

    # Scopes for common queries
    scope :recent, -> { order(created_at: :desc) }
    scope :for_user, ->(user) { where(user: user) }
    scope :for_email, ->(email) { where(email: email.downcase) }
    scope :for_ip, ->(ip) { where(ip_address: ip) }
    scope :for_website, ->(website) { where(website: website) }
    scope :failures, -> { where(event_type: %w[login_failure oauth_failure]) }
    scope :successes, -> { where(event_type: %w[login_success oauth_success]) }
    scope :today, -> { where('created_at >= ?', Time.current.beginning_of_day) }
    scope :last_hour, -> { where('created_at >= ?', 1.hour.ago) }
    scope :last_24_hours, -> { where('created_at >= ?', 24.hours.ago) }

    # Class methods for logging events
    class << self
      def log_login_success(user:, request:, website: nil)
        create_log(
          event_type: 'login_success',
          user: user,
          email: user.email,
          website: website || Pwb::Current.website,
          request: request
        )
      end

      def log_login_failure(email:, request:, reason: nil, website: nil)
        user = Pwb::User.find_by(email: email&.downcase)
        create_log(
          event_type: 'login_failure',
          user: user,
          email: email,
          failure_reason: reason,
          website: website || Pwb::Current.website,
          request: request
        )
      end

      def log_logout(user:, request:, website: nil)
        create_log(
          event_type: 'logout',
          user: user,
          email: user.email,
          website: website || Pwb::Current.website,
          request: request
        )
      end

      def log_oauth_success(user:, provider:, request:, website: nil)
        create_log(
          event_type: 'oauth_success',
          user: user,
          email: user.email,
          provider: provider,
          website: website || Pwb::Current.website,
          request: request
        )
      end

      def log_oauth_failure(email:, provider:, request:, reason: nil, website: nil)
        create_log(
          event_type: 'oauth_failure',
          email: email,
          provider: provider,
          failure_reason: reason,
          website: website || Pwb::Current.website,
          request: request
        )
      end

      def log_password_reset_request(email:, request:, website: nil)
        user = Pwb::User.find_by(email: email&.downcase)
        create_log(
          event_type: 'password_reset_request',
          user: user,
          email: email,
          website: website || Pwb::Current.website,
          request: request
        )
      end

      def log_password_reset_success(user:, request:, website: nil)
        create_log(
          event_type: 'password_reset_success',
          user: user,
          email: user.email,
          website: website || Pwb::Current.website,
          request: request
        )
      end

      def log_account_locked(user:, request: nil, website: nil)
        create_log(
          event_type: 'account_locked',
          user: user,
          email: user.email,
          failure_reason: "Locked after #{user.failed_attempts} failed attempts",
          website: website || Pwb::Current.website,
          request: request
        )
      end

      def log_account_unlocked(user:, request: nil, unlock_method: 'email', website: nil)
        create_log(
          event_type: 'account_unlocked',
          user: user,
          email: user.email,
          metadata: { unlock_method: unlock_method },
          website: website || Pwb::Current.website,
          request: request
        )
      end

      def log_session_timeout(user:, request: nil, website: nil)
        create_log(
          event_type: 'session_timeout',
          user: user,
          email: user.email,
          website: website || Pwb::Current.website,
          request: request
        )
      end

      def log_registration(user:, request:, website: nil)
        create_log(
          event_type: 'registration',
          user: user,
          email: user.email,
          website: website || Pwb::Current.website,
          request: request
        )
      end

      # Query helpers for security monitoring
      def failed_attempts_for_email(email, since: 1.hour.ago)
        for_email(email).failures.where('created_at >= ?', since).count
      end

      def failed_attempts_for_ip(ip, since: 1.hour.ago)
        for_ip(ip).failures.where('created_at >= ?', since).count
      end

      def suspicious_ips(threshold: 10, since: 1.hour.ago)
        where('created_at >= ?', since)
          .failures
          .group(:ip_address)
          .having('count(*) >= ?', threshold)
          .count
      end

      def recent_activity_for_user(user, limit: 20)
        for_user(user).recent.limit(limit)
      end

      private

      def create_log(event_type:, user: nil, email: nil, provider: nil,
                     failure_reason: nil, metadata: {}, website: nil, request: nil)
        create!(
          event_type: event_type,
          user: user,
          email: email&.downcase,
          provider: provider,
          failure_reason: failure_reason,
          metadata: metadata,
          website: website,
          ip_address: extract_ip(request),
          user_agent: extract_user_agent(request),
          request_path: extract_path(request)
        )
      rescue StandardError => e
        # Log creation failures should not break authentication flow
        Rails.logger.error("[AuthAuditLog] Failed to create audit log: #{e.message}")
        nil
      end

      def extract_ip(request)
        return nil unless request
        request.remote_ip || request.ip
      end

      def extract_user_agent(request)
        return nil unless request
        request.user_agent&.truncate(500)
      end

      def extract_path(request)
        return nil unless request
        request.fullpath&.truncate(500)
      end
    end

    private

    # Events that should trigger push notifications
    NOTIFIABLE_EVENTS = %w[
      login_failure
      account_locked
      password_reset_request
    ].freeze

    def send_security_notification
      return unless website&.ntfy_enabled?
      return unless NOTIFIABLE_EVENTS.include?(event_type)

      NtfyNotificationJob.perform_later(
        website.id,
        :security,
        nil,
        nil,
        event_type,
        {
          email: email,
          ip: ip_address,
          reason: failure_reason
        }
      )
    end
  end
end
