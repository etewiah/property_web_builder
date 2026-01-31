# frozen_string_literal: true

module Integrations
  module Providers
    # OpenRouter integration provider.
    #
    # Provides unified access to 100+ AI models from multiple providers
    # (Anthropic, OpenAI, Google, Meta, Mistral, etc.) through a single API.
    #
    # OpenRouter uses an OpenAI-compatible API, so we configure RubyLLM
    # with the OpenRouter API key and base URL.
    #
    # Required credentials:
    # - api_key: OpenRouter API key from openrouter.ai/keys
    #
    # Settings:
    # - default_model: Which model to use (in provider/model format)
    # - max_tokens: Maximum tokens in response
    #
    class OpenRouter < Base
      self.category = :ai
      self.display_name = 'OpenRouter'
      self.description = 'Access 100+ AI models from multiple providers through a single API'

      API_BASE_URL = 'https://openrouter.ai/api/v1'

      # Popular models available through OpenRouter
      # Format: [Display Name, provider/model-id]
      AVAILABLE_MODELS = [
        ['Claude 3.5 Sonnet (Anthropic)', 'anthropic/claude-3.5-sonnet'],
        ['Claude 3 Opus (Anthropic)', 'anthropic/claude-3-opus'],
        ['Claude 3 Haiku (Anthropic)', 'anthropic/claude-3-haiku'],
        ['GPT-4o (OpenAI)', 'openai/gpt-4o'],
        ['GPT-4o Mini (OpenAI)', 'openai/gpt-4o-mini'],
        ['GPT-4 Turbo (OpenAI)', 'openai/gpt-4-turbo'],
        ['Gemini Pro 1.5 (Google)', 'google/gemini-pro-1.5'],
        ['Llama 3.1 70B (Meta)', 'meta-llama/llama-3.1-70b-instruct'],
        ['Llama 3.1 8B (Meta)', 'meta-llama/llama-3.1-8b-instruct'],
        ['Mistral Large (Mistral)', 'mistralai/mistral-large'],
        ['Mixtral 8x7B (Mistral)', 'mistralai/mixtral-8x7b-instruct']
      ].freeze

      credential_field :api_key,
                       required: true,
                       label: 'API Key',
                       help: 'Get your API key from openrouter.ai/keys'

      setting_field :default_model,
                    type: :select,
                    options: AVAILABLE_MODELS,
                    default: 'anthropic/claude-3.5-sonnet',
                    label: 'Default Model',
                    help: 'The model to use for content generation'

      setting_field :max_tokens,
                    type: :number,
                    default: 4096,
                    label: 'Max Tokens',
                    help: 'Maximum number of tokens in generated responses'

      def validate_connection
        unless credentials_valid?
          errors.add(:base, 'API key is required')
          return false
        end

        # Validate by fetching the models list from OpenRouter
        response = Faraday.get("#{API_BASE_URL}/models") do |req|
          req.headers['Authorization'] = "Bearer #{credential(:api_key)}"
          req.options.timeout = 10
        end

        if response.status == 401
          errors.add(:base, 'Invalid API key')
          return false
        end

        response.success?
      rescue Faraday::Error => e
        errors.add(:base, "Connection failed: #{e.message}")
        false
      rescue StandardError => e
        errors.add(:base, "Connection failed: #{e.message}")
        false
      end
    end
  end
end

# Register with the integrations registry
Integrations::Registry.register(:ai, :open_router, Integrations::Providers::OpenRouter)
