# frozen_string_literal: true

module Integrations
  module Providers
    # Requesty integration provider.
    #
    # Provides unified access to 400+ AI models from multiple providers
    # (Anthropic, OpenAI, Google, DeepSeek, etc.) through a single
    # OpenAI-compatible API.
    #
    # Requesty exposes an OpenAI-compatible API, so we configure RubyLLM
    # with the Requesty API key and base URL.
    #
    # Required credentials:
    # - api_key: Requesty API key from app.requesty.ai/api-keys
    #
    # Settings:
    # - default_model: Which model to use (in provider/model format)
    # - max_tokens: Maximum tokens in response
    #
    class Requesty < Base
      self.category = :ai
      self.display_name = 'Requesty'
      self.description = 'Access 400+ AI models from multiple providers through a single OpenAI-compatible API'

      API_BASE_URL = 'https://router.requesty.ai/v1'

      # Popular models available through Requesty
      # Format: [Display Name, provider/model-id]
      AVAILABLE_MODELS = [
        ['Claude Sonnet 4.5 (Anthropic)', 'anthropic/claude-sonnet-4-5'],
        ['GPT-4o (OpenAI)', 'openai/gpt-4o'],
        ['GPT-4o Mini (OpenAI)', 'openai/gpt-4o-mini'],
        ['GPT-4.1 (OpenAI)', 'openai/gpt-4.1'],
        ['Gemini 2.5 Flash (Google)', 'google/gemini-2.5-flash'],
        ['Gemini 2.5 Pro (Google)', 'google/gemini-2.5-pro'],
        ['DeepSeek Chat (DeepSeek)', 'deepseek/deepseek-chat']
      ].freeze

      credential_field :api_key,
                       required: true,
                       label: 'API Key',
                       help: 'Get your API key from app.requesty.ai/api-keys'

      setting_field :default_model,
                    type: :select,
                    options: AVAILABLE_MODELS,
                    default: 'openai/gpt-4o-mini',
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

        # Validate by fetching the models list from Requesty
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
Integrations::Registry.register(:ai, :requesty, Integrations::Providers::Requesty)
