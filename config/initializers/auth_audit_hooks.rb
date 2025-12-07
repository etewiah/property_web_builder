# frozen_string_literal: true

# Warden hooks for audit logging of authentication events
#
# These hooks integrate with Devise/Warden to log all authentication events
# to the AuthAuditLog model for security monitoring and compliance.

# Log successful authentication (login)
Warden::Manager.after_authentication do |user, auth, opts|
  # Skip if this is a fetch from session (not a new login)
  next unless auth.winning_strategy

  request = auth.request

  # Determine if this is OAuth or regular login
  if (auth.winning_strategy && auth.winning_strategy.class.name.include?('OmniAuth')) ||
     request.path.include?('/auth/')
    provider = request.env.dig('omniauth.auth', 'provider') || 'oauth'
    Pwb::AuthAuditLog.log_oauth_success(
      user: user,
      provider: provider,
      request: request
    )
  else
    Pwb::AuthAuditLog.log_login_success(
      user: user,
      request: request
    )
  end
end

# Log logout
Warden::Manager.before_logout do |user, auth, opts|
  next unless user

  request = auth.request
  Pwb::AuthAuditLog.log_logout(
    user: user,
    request: request
  )
end

# Log failed authentication attempts
Warden::Manager.after_failed_fetch do |user, auth, opts|
  # This is called when session fetch fails, which happens on timeout
  # We handle this separately in the timeoutable hook
end

# Hook into Devise's failure app for login failures
# This is done via a custom failure app wrapper

module Pwb
  class AuthFailureApp < Devise::FailureApp
    def respond
      # Log the failure before responding
      log_authentication_failure
      super
    end

    # Override redirect_url to respect auth provider setting
    def redirect_url
      if Pwb::AuthConfig.firebase?
        stored_location = stored_location_for(:user)
        if stored_location.present?
          "/firebase_login?return_to=#{CGI.escape(stored_location)}"
        else
          '/firebase_login'
        end
      else
        super
      end
    end

    private

    def log_authentication_failure
      email = params.dig(:user, :email) || warden_options[:attempted_path]

      # Determine failure reason
      reason = case warden_message
               when :invalid
                 'invalid_credentials'
               when :locked
                 'account_locked'
               when :unconfirmed
                 'email_not_confirmed'
               when :not_found_in_database
                 'user_not_found'
               when :timeout
                 'session_timeout'
               when :inactive
                 'account_inactive'
               when :invalid_token
                 'invalid_token'
               else
                 warden_message.to_s
               end

      # Log the failure
      if reason == 'session_timeout' && warden_options[:user]
        Pwb::AuthAuditLog.log_session_timeout(
          user: warden_options[:user],
          request: request
        )
      else
        Pwb::AuthAuditLog.log_login_failure(
          email: email,
          reason: reason,
          request: request
        )
      end
    rescue StandardError => e
      Rails.logger.error("[AuthAuditLog] Failed to log auth failure: #{e.message}")
    end
  end
end

# Configure Devise to use our custom failure app
Rails.application.config.to_prepare do
  Devise.setup do |config|
    config.warden do |manager|
      manager.failure_app = Pwb::AuthFailureApp
    end
  end
end
