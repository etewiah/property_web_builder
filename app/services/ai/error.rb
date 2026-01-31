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
  # All errors include optional provider and model context for debugging.
  #
  class Error < StandardError
    attr_reader :provider, :model

    def initialize(message, provider: nil, model: nil)
      super(message)
      @provider = provider
      @model = model
    end
  end

  class ConfigurationError < Error; end
  class ApiError < Error; end
  class TimeoutError < Error; end
  class ContentPolicyError < Error; end

  class RateLimitError < Error
    attr_reader :retry_after

    def initialize(message, retry_after: 60, provider: nil, model: nil)
      super(message, provider: provider, model: model)
      @retry_after = retry_after
    end
  end
end
