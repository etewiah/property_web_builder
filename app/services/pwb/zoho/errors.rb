# frozen_string_literal: true

module Pwb
  module Zoho
    # Custom error classes for Zoho API
    #
    # Hierarchy:
    #   Error (base)
    #   ├── ConfigurationError  - Missing credentials
    #   ├── AuthenticationError - Invalid/expired tokens
    #   ├── ValidationError     - Invalid data sent to API
    #   ├── NotFoundError       - Resource not found
    #   ├── ApiError            - General API errors
    #   ├── TimeoutError        - Request timed out
    #   ├── ConnectionError     - Network issues
    #   └── RateLimitError      - Rate limit exceeded (includes retry_after)
    #
    class Error < StandardError; end

    class ConfigurationError < Error; end
    class AuthenticationError < Error; end
    class ValidationError < Error; end
    class NotFoundError < Error; end
    class ApiError < Error; end
    class TimeoutError < Error; end
    class ConnectionError < Error; end

    class RateLimitError < Error
      attr_reader :retry_after

      def initialize(message, retry_after: 60)
        super(message)
        @retry_after = retry_after
      end
    end
  end
end
