# frozen_string_literal: true

module Api
  # Base controller for all API endpoints
  # Provides JSON response handling, error handling, tenant resolution, and authentication
  #
  # Tenant Resolution:
  #   API requests can specify the tenant via:
  #   1. X-Website-Slug header (preferred for API clients)
  #   2. Subdomain (for browser-based requests)
  #
  #   In production, a tenant MUST be specified. In development/test,
  #   Website.first is used as a fallback.
  #
  class BaseController < ActionController::API
    include ActionController::Cookies

    before_action :set_default_format
    before_action :set_tenant_from_request

    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

    private

    def set_default_format
      request.format = :json
    end

    # Resolve tenant from request headers or subdomain
    # Sets ActsAsTenant.current_tenant for PwbTenant:: models
    def set_tenant_from_request
      @current_website = resolve_website

      if @current_website
        ActsAsTenant.current_tenant = @current_website
        Pwb::Current.website = @current_website
      elsif require_tenant?
        render json: {
          success: false,
          error: 'Missing or invalid tenant. Provide X-Website-Slug header or use subdomain.'
        }, status: :bad_request
      end
    end

    # Override in child controllers to require tenant
    def require_tenant?
      false
    end

    def current_website
      @current_website
    end

    def resolve_website
      website_from_header || website_from_subdomain || fallback_website
    end

    def website_from_header
      slug = request.headers['X-Website-Slug']
      return nil unless slug.present?

      Pwb::Website.find_by(subdomain: slug)
    end

    def website_from_subdomain
      subdomain = request.subdomain
      return nil if subdomain.blank? || subdomain == 'www'

      Pwb::Website.find_by(subdomain: subdomain)
    end

    def fallback_website
      return nil if Rails.env.production?

      Pwb::Website.first
    end

    def handle_standard_error(exception)
      Rails.logger.error "[API Error] #{exception.class}: #{exception.message}"
      Rails.logger.error exception.backtrace.first(10).join("\n")

      render json: {
        success: false,
        error: Rails.env.production? ? "An unexpected error occurred" : exception.message
      }, status: :internal_server_error
    end

    def handle_not_found(exception)
      render json: {
        success: false,
        error: "Resource not found"
      }, status: :not_found
    end

    def handle_validation_error(exception)
      render json: {
        success: false,
        error: exception.record.errors.full_messages.first,
        errors: exception.record.errors.full_messages
      }, status: :unprocessable_entity
    end

    def handle_parameter_missing(exception)
      render json: {
        success: false,
        error: "Missing required parameter: #{exception.param}"
      }, status: :bad_request
    end

    def json_response(data = nil, status: :ok, **kwargs)
      # Support both positional hash and keyword arguments
      response_data = data || kwargs
      render json: response_data, status: status
    end

    def success_response(status: :ok, **data)
      render json: { success: true }.merge(data), status: status
    end

    def error_response(message, status: :unprocessable_entity, errors: [])
      render json: {
        success: false,
        error: message,
        errors: errors.presence || [message]
      }, status: status
    end
  end
end
