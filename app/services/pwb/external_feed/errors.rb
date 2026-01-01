# frozen_string_literal: true

module Pwb
  module ExternalFeed
    # Container module for all external feed error classes
    module Errors
      # Base error class for all external feed errors
      class Error < StandardError; end

      # Raised when provider configuration is missing or invalid
      class ConfigurationError < Error; end

      # Raised when API authentication fails
      class AuthenticationError < Error; end

      # Raised when API rate limit is exceeded
      class RateLimitError < Error; end

      # Raised when the provider is temporarily unavailable
      class ProviderUnavailableError < Error; end

      # Raised when a requested property is not found
      class PropertyNotFoundError < Error; end

      # Raised when the API response is invalid or unexpected
      class InvalidResponseError < Error; end

      # Raised when a required feature is not supported by the provider
      class UnsupportedOperationError < Error; end
    end

    # Make error classes available at the ExternalFeed level for convenience
    Error = Errors::Error
    ConfigurationError = Errors::ConfigurationError
    AuthenticationError = Errors::AuthenticationError
    RateLimitError = Errors::RateLimitError
    ProviderUnavailableError = Errors::ProviderUnavailableError
    PropertyNotFoundError = Errors::PropertyNotFoundError
    InvalidResponseError = Errors::InvalidResponseError
    UnsupportedOperationError = Errors::UnsupportedOperationError
  end
end
