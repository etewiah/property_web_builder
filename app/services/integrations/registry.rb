# frozen_string_literal: true

module Integrations
  # Central registry of all available integration providers.
  #
  # Providers register themselves when loaded:
  #   Integrations::Registry.register(:ai, :anthropic, Integrations::Providers::Anthropic)
  #
  # Services can look up providers:
  #   provider_class = Integrations::Registry.provider(:ai, :anthropic)
  #   provider_class.new(integration).validate_connection
  #
  class Registry
    class << self
      def providers
        @providers ||= {}
      end

      # Register a provider for a category
      def register(category, provider, klass)
        providers[category.to_sym] ||= {}
        providers[category.to_sym][provider.to_sym] = klass
      end

      # Get a provider class
      def provider(category, provider)
        providers.dig(category.to_sym, provider.to_sym)
      end

      # Get all providers for a category
      def providers_for(category)
        providers[category.to_sym] || {}
      end

      # Get all registered categories
      def categories
        providers.keys
      end

      # Get all providers as a nested hash with metadata
      def all_providers
        providers.transform_values do |category_providers|
          category_providers.transform_values do |klass|
            {
              name: klass.display_name,
              description: klass.description,
              credential_fields: klass.credential_fields,
              setting_fields: klass.setting_fields
            }
          end
        end
      end

      # Check if a provider is registered
      def registered?(category, provider)
        provider(category, provider).present?
      end

      # Clear registry (useful for testing)
      def reset!
        @providers = {}
      end
    end
  end
end
