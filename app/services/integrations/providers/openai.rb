# frozen_string_literal: true

module Integrations
  module Providers
    # OpenAI integration provider.
    #
    # Provides access to GPT models for AI-powered content generation.
    #
    # Required credentials:
    # - api_key: OpenAI API key from platform.openai.com
    #
    # Settings:
    # - default_model: Which GPT model to use
    # - max_tokens: Maximum tokens in response
    # - organization_id: Optional organization ID
    #
    class Openai < Base
      self.category = :ai
      self.display_name = 'OpenAI'
      self.description = 'AI-powered content generation using GPT models'

      AVAILABLE_MODELS = [
        ['GPT-4o', 'gpt-4o'],
        ['GPT-4o Mini', 'gpt-4o-mini'],
        ['GPT-4 Turbo', 'gpt-4-turbo'],
        ['GPT-3.5 Turbo', 'gpt-3.5-turbo']
      ].freeze

      credential_field :api_key,
                       required: true,
                       label: 'API Key',
                       help: 'Get your API key from platform.openai.com'

      credential_field :organization_id,
                       required: false,
                       label: 'Organization ID',
                       help: 'Optional: Your OpenAI organization ID'

      setting_field :default_model,
                    type: :select,
                    options: AVAILABLE_MODELS,
                    default: 'gpt-4o-mini',
                    label: 'Default Model',
                    help: 'The GPT model to use for content generation'

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

        # Configure RubyLLM with the API key
        RubyLLM.configure do |config|
          config.openai_api_key = credential(:api_key)
          config.openai_organization_id = credential(:organization_id) if credential(:organization_id).present?
        end

        # Try a minimal API call to validate the key
        chat = RubyLLM.chat(model: setting(:default_model))
        chat.ask('Hello')

        true
      rescue RubyLLM::UnauthorizedError, RubyLLM::ForbiddenError => e
        errors.add(:base, 'Invalid API key')
        false
      rescue RubyLLM::Error => e
        errors.add(:base, "API error: #{e.message}")
        false
      rescue StandardError => e
        errors.add(:base, "Connection failed: #{e.message}")
        false
      end
    end
  end
end

# Register with the integrations registry
Integrations::Registry.register(:ai, :openai, Integrations::Providers::Openai)
