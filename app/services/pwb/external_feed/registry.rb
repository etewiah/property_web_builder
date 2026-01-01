# frozen_string_literal: true

module Pwb
  module ExternalFeed
    # Registry for external feed providers.
    # Providers register themselves here and can be looked up by name.
    class Registry
      class << self
        # Register a provider class
        # @param provider_class [Class] A class that inherits from BaseProvider
        def register(provider_class)
          unless provider_class.respond_to?(:provider_name)
            raise ArgumentError, "Provider must implement .provider_name class method"
          end

          name = provider_class.provider_name.to_sym
          providers[name] = provider_class

          Rails.logger.info("[ExternalFeed::Registry] Registered provider: #{name}")
        end

        # Find a provider class by name
        # @param name [Symbol, String] The provider name
        # @return [Class, nil] The provider class or nil if not found
        def find(name)
          providers[name.to_sym]
        end

        # Check if a provider is registered
        # @param name [Symbol, String] The provider name
        # @return [Boolean]
        def registered?(name)
          providers.key?(name.to_sym)
        end

        # List all registered provider names
        # @return [Array<Symbol>]
        def available_providers
          providers.keys
        end

        # Clear all registered providers (useful for testing)
        def clear!
          @providers = {}
        end

        private

        def providers
          @providers ||= {}
        end
      end
    end
  end
end
