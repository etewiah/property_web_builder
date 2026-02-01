# frozen_string_literal: true

module ApiManage
  module V1
    # Base controller for api_manage endpoints
    #
    # Provides API access for managing website content.
    # Used by external clients like Astro.js admin UIs.
    #
    # Authentication:
    # - Session-based: For same-origin requests from logged-in users
    # - API Key: Via X-API-Key header for external integrations
    # - User header: Via X-User-Email for development/testing
    #
    class BaseController < ActionController::Base
      include SubdomainTenant
      include ActiveStorage::SetCurrent
      include ErrorHandling

      skip_before_action :verify_authenticity_token

      # Require website context for all API requests
      before_action :require_website!

      # JSON API responses
      rescue_from ActiveRecord::RecordNotFound do |e|
        StructuredLogger.warn("[API] Record not found", path: request.path, error: e.message)
        render json: { success: false, error: 'Not found', message: e.message }, status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        StructuredLogger.info("[API] Validation failed", path: request.path, errors: e.record.errors.to_hash)
        render json: { success: false, error: 'Validation failed', errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      rescue_from ActionController::ParameterMissing do |e|
        StructuredLogger.warn("[API] Parameter missing", path: request.path, param: e.param.to_s)
        render json: { success: false, error: 'Bad request', message: e.message }, status: :bad_request
      end

      private

      def current_website
        Pwb::Current.website
      end

      # Ensures a valid website context exists for all requests.
      # Returns 400 Bad Request if website cannot be determined.
      def require_website!
        return if current_website.present?

        render json: {
          error: 'Website context required',
          message: 'Unable to determine website from request. Provide X-Website-Slug header or use a valid subdomain.'
        }, status: :bad_request
      end

      # Returns the current authenticated user.
      # Tries multiple authentication methods in order:
      # 1. Devise session (for same-origin requests)
      # 2. API key lookup (for external integrations)
      # 3. User email header (for development/testing only)
      def current_user
        @current_user ||= authenticate_from_session ||
                          authenticate_from_api_key ||
                          authenticate_from_header
      end

      # Authenticate via Devise session (same-origin requests)
      def authenticate_from_session
        return nil unless respond_to?(:warden, true) && warden&.user

        user = warden.user
        return user if user_authorized_for_website?(user)

        nil
      end

      # Authenticate via X-API-Key header
      def authenticate_from_api_key
        api_key = request.headers['X-API-Key']
        return nil if api_key.blank?

        # Find integration with this API key for current website
        integration = current_website&.integrations&.find_by(api_key: api_key, active: true)
        return nil unless integration

        # Return the website owner or first admin as the acting user
        current_website.users.joins(:user_memberships)
                       .where(pwb_user_memberships: { role: %w[owner admin], active: true })
                       .first
      end

      # Authenticate via X-User-Email header (development/testing only)
      def authenticate_from_header
        return nil unless Rails.env.development? || Rails.env.test?

        email = request.headers['X-User-Email']
        return nil if email.blank?

        user = Pwb::User.find_by(email: email)
        return user if user && user_authorized_for_website?(user)

        nil
      end

      # Check if user has access to current website
      def user_authorized_for_website?(user)
        return false unless user && current_website

        user.can_access_website?(current_website)
      end

      # Require authenticated user for protected actions
      def require_user!
        return if current_user.present?

        render json: {
          error: 'Authentication required',
          message: 'Please provide valid authentication credentials.'
        }, status: :unauthorized
      end

      # Require admin role for admin-only actions
      def require_admin!
        require_user!
        return if performed?
        return if current_user.admin_for_website?(current_website)

        render json: {
          error: 'Admin access required',
          message: 'This action requires administrator privileges.'
        }, status: :forbidden
      end
    end
  end
end
