# frozen_string_literal: true

module ApiPublic
  # Concern for standardized error handling across API controllers
  # Provides rescue handlers and error rendering
  module ErrorHandler
    extend ActiveSupport::Concern

    included do
      # Rescue from custom API errors
      rescue_from ApiPublic::Errors::ApiError, with: :render_api_error

      # Rescue from ActiveRecord errors
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error

      # Rescue from parameter errors
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
    end

    private

    # Render a standardized API error response
    def render_api_error(error)
      # Add request ID for debugging
      error_response = {
        error: error.to_h.merge(request_id: request.uuid)
      }

      # Add retry-after header for rate limiting
      if error.is_a?(ApiPublic::Errors::RateLimitedError)
        response.headers["Retry-After"] = error.retry_after.to_s
      end

      render json: error_response, status: error.status
    end

    # Handle ActiveRecord::RecordNotFound
    def render_not_found(exception)
      model_name = exception.model || "Resource"
      message = "#{model_name} not found"

      render json: {
        error: {
          code: "NOT_FOUND",
          message: message,
          status: 404,
          request_id: request.uuid
        }
      }, status: :not_found
    end

    # Handle ActiveRecord::RecordInvalid
    def render_validation_error(exception)
      errors = exception.record&.errors&.to_hash || {}

      render json: {
        error: {
          code: "VALIDATION_FAILED",
          message: "Validation failed",
          status: 422,
          details: { validation_errors: errors },
          request_id: request.uuid
        }
      }, status: :unprocessable_entity
    end

    # Handle ActionController::ParameterMissing
    def render_parameter_missing(exception)
      render json: {
        error: {
          code: "VALIDATION_FAILED",
          message: "Missing required parameter: #{exception.param}",
          status: 400,
          details: { missing_param: exception.param.to_s },
          request_id: request.uuid
        }
      }, status: :bad_request
    end

    # Generic 404 helper
    def render_not_found_error(message = "Resource not found", code: "NOT_FOUND")
      render json: {
        error: {
          code: code,
          message: message,
          status: 404,
          request_id: request.uuid
        }
      }, status: :not_found
    end

    # Generic 400 helper
    def render_bad_request(message, code: "BAD_REQUEST", details: {})
      render json: {
        error: {
          code: code,
          message: message,
          status: 400,
          details: details.presence,
          request_id: request.uuid
        }.compact
      }, status: :bad_request
    end
  end
end
