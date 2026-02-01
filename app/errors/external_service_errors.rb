# frozen_string_literal: true

# External service related errors
#
# These errors are raised when external API calls fail.
#

# Base class for external service errors
class ExternalServiceError < ApplicationError
  attr_reader :service_name, :original_error

  def initialize(message = nil, service_name: nil, original_error: nil, details: {})
    @service_name = service_name
    @original_error = original_error

    details[:service] = service_name if service_name
    details[:original_error] = original_error&.message if original_error

    super(
      message || "External service error",
      code: "EXTERNAL_SERVICE_ERROR",
      details: details,
      http_status: :bad_gateway
    )
  end

  def to_log_hash
    super.merge(
      service_name: service_name,
      original_error_class: original_error&.class&.name,
      original_error_message: original_error&.message
    ).compact
  end
end

# Raised when an external API times out
class ExternalServiceTimeoutError < ExternalServiceError
  def initialize(message = nil, service_name: nil, timeout_seconds: nil, details: {})
    details[:timeout_seconds] = timeout_seconds if timeout_seconds
    super(
      message || "External service request timed out",
      service_name: service_name,
      details: details
    )
    @code = "EXTERNAL_SERVICE_TIMEOUT"
    @http_status = :gateway_timeout
  end
end

# Raised when an external API returns an error response
class ExternalServiceApiError < ExternalServiceError
  attr_reader :status_code, :response_body

  def initialize(message = nil, service_name: nil, status_code: nil, response_body: nil, details: {})
    @status_code = status_code
    @response_body = response_body

    details[:status_code] = status_code if status_code
    details[:response_body] = truncate_response(response_body) if response_body

    super(
      message || "External service returned an error",
      service_name: service_name,
      details: details
    )
    @code = "EXTERNAL_SERVICE_API_ERROR"
  end

  private

  def truncate_response(body)
    return body if body.nil? || body.length <= 500
    "#{body[0..500]}... (truncated)"
  end
end

# Raised when an external service rate limits our requests
class ExternalServiceRateLimitError < ExternalServiceError
  attr_reader :retry_after

  def initialize(message = nil, service_name: nil, retry_after: nil, details: {})
    @retry_after = retry_after
    details[:retry_after] = retry_after if retry_after

    super(
      message || "External service rate limit exceeded",
      service_name: service_name,
      details: details
    )
    @code = "EXTERNAL_SERVICE_RATE_LIMITED"
    @http_status = :too_many_requests
  end
end

# Raised when external service credentials are missing or invalid
class ExternalServiceConfigurationError < ExternalServiceError
  def initialize(message = nil, service_name: nil, missing_config: nil, details: {})
    details[:missing_config] = missing_config if missing_config

    super(
      message || "External service not configured",
      service_name: service_name,
      details: details
    )
    @code = "EXTERNAL_SERVICE_NOT_CONFIGURED"
    @http_status = :service_unavailable
  end
end
