# frozen_string_literal: true

require_relative 'error'

module Ai
  # Base class for AI services providing common functionality
  #
  # Features:
  # - Client initialization with provider configuration
  # - Structured logging
  # - Error handling and retry logic
  # - Token usage tracking
  #
  class BaseService
    DEFAULT_MODEL = 'claude-sonnet-4-20250514'
    DEFAULT_PROVIDER = 'anthropic'

    def initialize(website: nil, user: nil)
      @website = website
      @user = user
    end

    protected

    def client
      ensure_configured!
      @client ||= RubyLLM.client
    end

    def chat(messages:, model: nil, **options)
      selected_model = model || DEFAULT_MODEL

      log_request(messages: messages, model: selected_model) do
        response = RubyLLM.chat(
          messages: messages,
          model: selected_model,
          **options
        )

        log_response(response)
        response
      end
    rescue RubyLLM::RateLimitError => e
      raise RateLimitError.new(e.message, retry_after: e.retry_after || 60)
    rescue RubyLLM::ContentPolicyError => e
      raise ContentPolicyError, e.message
    rescue RubyLLM::Error => e
      raise ApiError, "AI API error: #{e.message}"
    rescue Timeout::Error, Net::ReadTimeout => e
      raise TimeoutError, "AI request timed out: #{e.message}"
    end

    def configured?
      ENV['ANTHROPIC_API_KEY'].present? || ENV['OPENAI_API_KEY'].present?
    end

    def ensure_configured!
      return if configured?

      raise ConfigurationError, "AI is not configured. Set ANTHROPIC_API_KEY or OPENAI_API_KEY environment variable."
    end

    def create_generation_request(type:, prop: nil, input_data: {}, locale: 'en')
      Pwb::AiGenerationRequest.create!(
        website: @website,
        user: @user,
        prop: prop,
        request_type: type,
        ai_provider: DEFAULT_PROVIDER,
        ai_model: DEFAULT_MODEL,
        input_data: input_data,
        locale: locale,
        status: 'pending'
      )
    end

    private

    def log_request(messages:, model:, &block)
      Rails.logger.info "[AI] Request to #{model} with #{messages.length} messages"
      start_time = Time.current

      result = yield

      duration = Time.current - start_time
      Rails.logger.info "[AI] Completed in #{duration.round(2)}s"
      result
    end

    def log_response(response)
      if response.respond_to?(:usage)
        Rails.logger.info "[AI] Tokens - Input: #{response.usage&.input_tokens}, Output: #{response.usage&.output_tokens}"
      end
    end
  end
end
