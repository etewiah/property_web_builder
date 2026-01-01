# frozen_string_literal: true

module Pwb
  module ExternalFeed
    # Abstract base class for external feed providers.
    # All providers must inherit from this class and implement the required methods.
    class BaseProvider
      attr_reader :website, :config

      # Initialize with website and provider configuration
      # @param website [Pwb::Website] The website using this provider
      # @param config [Hash] Provider-specific configuration
      def initialize(website, config)
        @website = website
        @config = (config || {}).deep_symbolize_keys
        validate_config!
      end

      # Search for properties
      # @param params [Hash] Normalized search parameters
      #   - locale [Symbol, String] Language code (en, es, fr, etc.)
      #   - listing_type [Symbol] :sale or :rental
      #   - property_types [Array<String>] Property type codes
      #   - location [String] Location/city name
      #   - min_bedrooms [Integer]
      #   - max_bedrooms [Integer]
      #   - min_bathrooms [Integer]
      #   - max_bathrooms [Integer]
      #   - min_price [Integer]
      #   - max_price [Integer]
      #   - min_area [Integer] Built area in sqm
      #   - max_area [Integer]
      #   - features [Array<String>] Required features
      #   - sort [Symbol] :price_asc, :price_desc, :newest, :updated
      #   - page [Integer] Page number (1-indexed)
      #   - per_page [Integer] Results per page
      # @return [NormalizedSearchResult]
      def search(params)
        raise NotImplementedError, "#{self.class} must implement #search"
      end

      # Find a single property by reference
      # @param reference [String] Provider's property reference
      # @param params [Hash] Additional parameters
      #   - locale [Symbol, String] Language code
      #   - listing_type [Symbol] :sale or :rental
      # @return [NormalizedProperty, nil]
      def find(reference, params = {})
        raise NotImplementedError, "#{self.class} must implement #find"
      end

      # Find similar properties
      # @param property [NormalizedProperty] The property to find similar to
      # @param params [Hash] Additional parameters
      #   - limit [Integer] Max results (default: 6)
      # @return [Array<NormalizedProperty>]
      def similar(property, params = {})
        raise NotImplementedError, "#{self.class} must implement #similar"
      end

      # Get available locations for search filters
      # @param params [Hash] Filter parameters
      # @return [Array<Hash>] Location options with :value and :label
      def locations(params = {})
        raise NotImplementedError, "#{self.class} must implement #locations"
      end

      # Get available property types for search filters
      # @param params [Hash] Filter parameters
      # @return [Array<Hash>] Property type options with :value and :label
      def property_types(params = {})
        raise NotImplementedError, "#{self.class} must implement #property_types"
      end

      # Check if provider is properly configured and accessible
      # @return [Boolean]
      def available?
        raise NotImplementedError, "#{self.class} must implement #available?"
      end

      # Provider identifier - must be implemented by subclasses
      # @return [Symbol]
      def self.provider_name
        raise NotImplementedError, "#{self} must implement .provider_name"
      end

      # Human-readable provider name
      # @return [String]
      def self.display_name
        provider_name.to_s.titleize
      end

      protected

      # Validate required configuration keys
      # Raises ConfigurationError if required keys are missing
      def validate_config!
        missing = required_config_keys.map(&:to_sym) - config.keys
        if missing.any?
          raise ConfigurationError,
                "Missing required configuration for #{self.class.provider_name}: #{missing.join(', ')}"
        end
      end

      # Override in subclasses to specify required config keys
      # @return [Array<Symbol>]
      def required_config_keys
        []
      end

      # Get config value with optional default
      # @param key [Symbol] Configuration key
      # @param default [Object] Default value if key not present
      # @return [Object]
      def config_value(key, default = nil)
        config.fetch(key.to_sym, default)
      end

      # Check if a config key is present and truthy
      # @param key [Symbol] Configuration key
      # @return [Boolean]
      def config_enabled?(key)
        !!config[key.to_sym]
      end

      # Get the default locale from config or fallback to :en
      # @return [Symbol]
      def default_locale
        (config[:default_locale] || "en").to_sym
      end

      # Get supported locales from config
      # @return [Array<Symbol>]
      def supported_locales
        locales = config[:supported_locales] || ["en"]
        locales.map(&:to_sym)
      end

      # Check if a locale is supported
      # @param locale [Symbol, String] The locale to check
      # @return [Boolean]
      def locale_supported?(locale)
        supported_locales.include?(locale.to_sym)
      end

      # Get the default results per page
      # @return [Integer]
      def default_per_page
        (config[:results_per_page] || 24).to_i
      end

      # Log a message with provider context
      # @param level [Symbol] Log level (:debug, :info, :warn, :error)
      # @param message [String] Log message
      def log(level, message)
        Rails.logger.public_send(level, "[ExternalFeed::#{self.class.provider_name}] #{message}")
      end
    end
  end
end
