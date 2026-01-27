# frozen_string_literal: true

module ApiManage
  module V1
    # Base controller for api_manage endpoints
    #
    # Provides API access for managing website content.
    # Used by external clients like Astro.js admin UIs.
    #
    # TODO: Implement authentication (Firebase token / API key)
    # For now, authentication is bypassed for development.
    #
    class BaseController < ActionController::Base
      include SubdomainTenant
      include ActiveStorage::SetCurrent

      skip_before_action :verify_authenticity_token

      # TODO: Add authentication before_action
      # before_action :authenticate_api_user!
      # before_action :require_admin!

      # JSON API responses
      rescue_from ActiveRecord::RecordNotFound do |e|
        render json: { error: 'Not found', message: e.message }, status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render json: { error: 'Validation failed', errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      rescue_from ActionController::ParameterMissing do |e|
        render json: { error: 'Bad request', message: e.message }, status: :bad_request
      end

      private

      def current_website
        Pwb::Current.website
      end
    end
  end
end
