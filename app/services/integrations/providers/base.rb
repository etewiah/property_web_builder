# frozen_string_literal: true

module Integrations
  module Providers
    # Base class for integration providers.
    #
    # Subclasses define:
    # - credential_field declarations for required secrets
    # - setting_field declarations for configuration options
    # - validate_connection method to test the integration
    #
    # Example:
    #   class Anthropic < Base
    #     self.category = :ai
    #     self.display_name = 'Anthropic'
    #     self.description = 'AI assistant powered by Claude'
    #
    #     credential_field :api_key, required: true, label: 'API Key'
    #     setting_field :default_model, type: :select, options: [...], default: '...'
    #
    #     def validate_connection
    #       # Test API key
    #     end
    #   end
    #
    class Base
      include ActiveModel::Validations

      class_attribute :category
      class_attribute :display_name
      class_attribute :description
      class_attribute :credential_fields, default: {}
      class_attribute :setting_fields, default: {}

      attr_reader :integration

      def initialize(integration)
        @integration = integration
      end

      # DSL for defining credential fields
      class << self
        def credential_field(name, required: false, label: nil, help: nil)
          self.credential_fields = credential_fields.merge(
            name.to_sym => {
              required: required,
              label: label || name.to_s.titleize,
              help: help
            }
          )
        end

        def setting_field(name, type: :string, options: nil, default: nil, label: nil, help: nil)
          self.setting_fields = setting_fields.merge(
            name.to_sym => {
              type: type,
              options: options,
              default: default,
              label: label || name.to_s.titleize,
              help: help
            }
          )
        end

        def default_for(key)
          setting_fields.dig(key.to_sym, :default)
        end

        def required_credentials
          credential_fields.select { |_, v| v[:required] }.keys
        end
      end

      # Credential accessor
      def credential(key)
        integration.credential(key)
      end

      # Setting accessor with default fallback
      def setting(key)
        value = integration.setting(key)
        value.presence || self.class.default_for(key)
      end

      # Override in subclasses to test the connection
      def validate_connection
        raise NotImplementedError, "#{self.class} must implement #validate_connection"
      end

      # Check if all required credentials are present
      def credentials_valid?
        self.class.required_credentials.all? do |key|
          credential(key).present?
        end
      end

      # Helper to record usage on the integration
      def record_usage!
        integration.record_usage!
      end

      # Helper to record errors on the integration
      def record_error!(message)
        integration.record_error!(message)
      end
    end
  end
end
