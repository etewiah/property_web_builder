# frozen_string_literal: true

# Base error class for all application-specific errors
#
# Provides structured error information for logging and API responses.
# All domain-specific errors should inherit from this class.
#
# Usage:
#   raise ApplicationError.new("Something went wrong", code: "GENERIC_ERROR")
#   raise TenantNotFoundError.new("Website not found")
#
# Logging:
#   rescue ApplicationError => e
#     Rails.logger.error(e.to_log_hash)
#
class ApplicationError < StandardError
  attr_reader :code, :details, :http_status

  # @param message [String] Human-readable error message
  # @param code [String, nil] Machine-readable error code (defaults to class name)
  # @param details [Hash] Additional context for debugging
  # @param http_status [Symbol] HTTP status code for API responses (default: :internal_server_error)
  def initialize(message = nil, code: nil, details: {}, http_status: :internal_server_error)
    @code = code || self.class.name.demodulize.underscore.upcase
    @details = details
    @http_status = http_status
    super(message || default_message)
  end

  # Returns a hash suitable for structured logging
  # @return [Hash]
  def to_log_hash
    {
      error_class: self.class.name,
      error_code: code,
      message: message,
      details: details.presence
    }.compact
  end

  # Returns a hash suitable for JSON API responses
  # @return [Hash]
  def to_api_response
    {
      error: code,
      message: message,
      details: details.presence
    }.compact
  end

  private

  def default_message
    "An error occurred"
  end
end
