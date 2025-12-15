# frozen_string_literal: true

# Authentication Provider Configuration
#
# This module allows switching between Firebase and Devise authentication
# across the entire application via a single environment variable.
#
# Usage:
#   Set AUTH_PROVIDER environment variable to 'firebase' or 'devise'
#
# Examples:
#   AUTH_PROVIDER=firebase  # Use Firebase authentication (default)
#   AUTH_PROVIDER=devise    # Use traditional Devise authentication
#
module Pwb
  module AuthConfig
    VALID_PROVIDERS = %i[firebase devise].freeze

    class << self
      def provider
        @provider ||= ENV.fetch('AUTH_PROVIDER', 'firebase').to_sym
      end

      def provider=(value)
        value = value.to_sym
        unless VALID_PROVIDERS.include?(value)
          raise ArgumentError, "Invalid auth provider: #{value}. Valid options: #{VALID_PROVIDERS.join(', ')}"
        end
        @provider = value
      end

      def firebase?
        provider == :firebase
      end

      def devise?
        provider == :devise
      end

      def login_path(locale: nil)
        if firebase?
          '/pwb_login'
        else
          locale ? "/#{locale}/users/sign_in" : '/users/sign_in'
        end
      end

      def signup_path(locale: nil)
        if firebase?
          '/pwb_sign_up'
        else
          locale ? "/#{locale}/users/sign_up" : '/users/sign_up'
        end
      end

      def forgot_password_path(locale: nil)
        if firebase?
          '/pwb_forgot_password'
        else
          locale ? "/#{locale}/users/password/new" : '/users/password/new'
        end
      end

      def logout_path
        '/auth/logout'
      end

      # Returns configuration summary for debugging
      def config_summary
        {
          provider: provider,
          firebase_configured: firebase_configured?,
          login_path: login_path,
          signup_path: signup_path,
          logout_path: logout_path
        }
      end

      # Check if Firebase is properly configured
      def firebase_configured?
        ENV['FIREBASE_API_KEY'].present? && ENV['FIREBASE_PROJECT_ID'].present?
      end

      # Validate configuration on boot
      def validate!
        if firebase? && !firebase_configured?
          Rails.logger.warn "[Pwb::AuthConfig] Firebase auth enabled but FIREBASE_API_KEY or FIREBASE_PROJECT_ID not set"
        end
      end
    end
  end
end

# Validate configuration after Rails initializes
Rails.application.config.after_initialize do
  Pwb::AuthConfig.validate!
  Rails.logger.info "[Pwb::AuthConfig] Using #{Pwb::AuthConfig.provider} authentication"
end
