# frozen_string_literal: true

module Api
  # Base controller for all API endpoints
  # Provides JSON response handling, error handling, and authentication
  class BaseController < ActionController::API
    include ActionController::Cookies

    before_action :set_default_format

    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

    private

    def set_default_format
      request.format = :json
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
