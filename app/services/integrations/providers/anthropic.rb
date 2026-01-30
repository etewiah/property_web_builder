# frozen_string_literal: true

module Integrations
  module Providers
    # Anthropic AI integration provider.
    #
    # Provides access to Claude models for AI-powered content generation.
    #
    # Required credentials:
    # - api_key: Anthropic API key from console.anthropic.com
    #
    # Settings:
    # - default_model: Which Claude model to use
    # - max_tokens: Maximum tokens in response
    #
    class Anthropic < Base
      self.category = :ai
      self.display_name = 'Anthropic'
      self.description = 'AI-powered content generation using Claude models'

      AVAILABLE_MODELS = [
        ['Claude Sonnet 4', 'claude-sonnet-4-20250514'],
        ['Claude Opus 4', 'claude-opus-4-20250514'],
        ['Claude Haiku 3.5', 'claude-3-5-haiku-20241022']
      ].freeze

      credential_field :api_key,
                       required: true,
                       label: 'API Key',
                       help: 'Get your API key from console.anthropic.com'

      setting_field :default_model,
                    type: :select,
                    options: AVAILABLE_MODELS,
                    default: 'claude-sonnet-4-20250514',
                    label: 'Default Model',
                    help: 'The Claude model to use for content generation'

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
          config.anthropic_api_key = credential(:api_key)
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
Integrations::Registry.register(:ai, :anthropic, Integrations::Providers::Anthropic)
