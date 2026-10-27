# frozen_string_literal: true

module Integrations
  module Providers
    # Cheaper Inference integration provider.
    #
    # Cheaper Inference is an OpenAI-compatible LLM gateway. One API key
    # gives access to models from several labs.
    #
    # Cheaper Inference exposes an OpenAI-compatible API, so we configure
    # RubyLLM with the Cheaper Inference API key and base URL.
    #
    # Required credentials:
    # - api_key: Cheaper Inference API key from cheaperinference.com
    #
    # Settings:
    # - default_model: Which model to use (bare model id)
    # - max_tokens: Maximum tokens in response
    #
    class CheaperInference < Base
      self.category = :ai
      self.display_name = 'Cheaper Inference'
      self.description = 'OpenAI-compatible LLM gateway with one API key for models from several labs'

      API_BASE_URL = 'https://api.cheaperinference.com/v1'

      # Models available through Cheaper Inference.
      # RubyLLM resolves these ids to its OpenAI provider, which
      # Ai::BaseService points at the Cheaper Inference base URL.
      # Format: [Display Name, model-id]
      AVAILABLE_MODELS = [
        ['GPT-5.4 Mini', 'gpt-5.4-mini'],
        ['GPT-5.4', 'gpt-5.4'],
        ['GPT-5.5', 'gpt-5.5'],
        ['GPT-5 Mini', 'gpt-5-mini'],
        ['GPT-4.1', 'gpt-4.1'],
        ['GPT-4.1 Mini', 'gpt-4.1-mini'],
        ['GPT-4o Mini', 'gpt-4o-mini']
      ].freeze

      credential_field :api_key,
                       required: true,
                       label: 'API Key',
                       help: 'Get your API key from cheaperinference.com'

      setting_field :default_model,
                    type: :select,
                    options: AVAILABLE_MODELS,
                    default: 'gpt-5.4-mini',
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

        # Validate by fetching the models list from Cheaper Inference
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
Integrations::Registry.register(:ai, :cheaper_inference, Integrations::Providers::CheaperInference)
