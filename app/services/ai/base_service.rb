# frozen_string_literal: true

require_relative 'error'

module Ai
  # Base class for AI services providing common functionality.
  #
  # Uses the website's configured AI integration for credentials and settings.
  # Falls back to environment variables if no integration is configured.
  #
  # Features:
  # - Integration-based configuration (per-website API keys)
  # - Fallback to ENV variables for backward compatibility
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
      @integration = website&.integration_for(:ai)
    end

    protected

    def chat(messages:, model: nil, **options)
      ensure_configured!
      configure_ruby_llm!

      selected_model = model || default_model

      log_request(messages: messages, model: selected_model) do
        # Create a chat instance with the specified model
        chat_instance = RubyLLM.chat(model: selected_model)

        # Build the conversation from messages array
        # Messages format: [{ role: 'user', content: '...' }, ...]
        response = nil
        messages.each do |msg|
          if msg[:role] == 'system'
            chat_instance.with_instructions(msg[:content])
          elsif msg[:role] == 'user'
            response = chat_instance.ask(msg[:content])
          end
        end

        # Record usage on the integration
        @integration&.record_usage!

        log_response(response)
        response
      end
    rescue RubyLLM::RateLimitError => e
      @integration&.record_error!("Rate limit exceeded")
      raise RateLimitError.new(e.message, retry_after: e.respond_to?(:retry_after) ? e.retry_after : 60)
    rescue RubyLLM::ForbiddenError => e
      @integration&.record_error!(e.message)
      raise ContentPolicyError, e.message
    rescue RubyLLM::UnauthorizedError => e
      @integration&.record_error!("Invalid API key")
      raise ConfigurationError, "Invalid API key. Please check your AI integration settings."
    rescue RubyLLM::Error => e
      @integration&.record_error!(e.message)
      raise ApiError, "AI API error: #{e.message}"
    rescue Timeout::Error, Net::ReadTimeout => e
      @integration&.record_error!(e.message)
      raise TimeoutError, "AI request timed out: #{e.message}"
    end

    def configured?
      # Check integration first, then fall back to ENV
      if @integration&.credentials_present?
        true
      else
        ENV['ANTHROPIC_API_KEY'].present? || ENV['OPENAI_API_KEY'].present?
      end
    end

    def ensure_configured!
      return if configured?

      raise ConfigurationError, "AI is not configured. Please configure an AI integration in Site Admin > Integrations, or set ANTHROPIC_API_KEY environment variable."
    end

    def create_generation_request(type:, prop: nil, input_data: {}, locale: 'en')
      Pwb::AiGenerationRequest.create!(
        website: @website,
        user: @user,
        prop: prop,
        request_type: type,
        ai_provider: current_provider,
        ai_model: default_model,
        input_data: input_data,
        locale: locale,
        status: 'pending'
      )
    end

    private

    # Configure RubyLLM with API keys from integration or ENV
    def configure_ruby_llm!
      RubyLLM.configure do |config|
        if @integration&.credentials_present?
          # Use integration credentials
          case @integration.provider
          when 'anthropic'
            config.anthropic_api_key = @integration.credential(:api_key)
          when 'openai'
            config.openai_api_key = @integration.credential(:api_key)
            org_id = @integration.credential(:organization_id)
            config.openai_organization_id = org_id if org_id.present?
          when 'open_router'
            # OpenRouter uses OpenAI-compatible API with custom base URL
            config.openai_api_key = @integration.credential(:api_key)
            config.openai_api_base = Integrations::Providers::OpenRouter::API_BASE_URL
          end
        else
          # Fall back to ENV variables
          config.anthropic_api_key = ENV['ANTHROPIC_API_KEY'] if ENV['ANTHROPIC_API_KEY'].present?
          config.openai_api_key = ENV['OPENAI_API_KEY'] if ENV['OPENAI_API_KEY'].present?
        end
      end
    end

    def default_model
      @integration&.setting(:default_model) || DEFAULT_MODEL
    end

    def current_provider
      @integration&.provider || DEFAULT_PROVIDER
    end

    def log_request(messages:, model:, &block)
      Rails.logger.info "[AI] Request to #{model} with #{messages.length} messages"
      start_time = Time.current

      result = yield

      duration = Time.current - start_time
      Rails.logger.info "[AI] Completed in #{duration.round(2)}s"
      result
    end

    def log_response(response)
      return unless response

      # RubyLLM::Message has tokens directly on the object
      input = response.respond_to?(:input_tokens) ? response.input_tokens : response.usage&.input_tokens
      output = response.respond_to?(:output_tokens) ? response.output_tokens : response.usage&.output_tokens
      Rails.logger.info "[AI] Tokens - Input: #{input}, Output: #{output}" if input || output
    end
  end
end
