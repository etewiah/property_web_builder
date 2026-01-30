# frozen_string_literal: true

module Ai
  # Custom error classes for AI services
  #
  # Hierarchy:
  #   Error (base)
  #   +-- ConfigurationError  - Missing API keys or invalid configuration
  #   +-- ApiError            - General API errors
  #   +-- RateLimitError      - Rate limit exceeded (includes retry_after)
  #   +-- ContentPolicyError  - Content blocked due to policy violations
  #   +-- TimeoutError        - Request timed out
  #
  class Error < StandardError; end

  class ConfigurationError < Error; end
  class ApiError < Error; end
  class TimeoutError < Error; end
  class ContentPolicyError < Error; end

  class RateLimitError < Error
    attr_reader :retry_after

    def initialize(message, retry_after: 60)
      super(message)
      @retry_after = retry_after
    end
  end
end
