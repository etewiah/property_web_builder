# frozen_string_literal: true

module Pwb
  # Stores external service integrations for each website (tenant).
  #
  # Provides a flexible, secure way to configure connections to external
  # services like AI providers, CRMs, email marketing platforms, etc.
  #
  # Credentials are encrypted at rest using Rails ActiveRecord::Encryption.
  #
  # Usage:
  #   # Get configured AI integration for a website
  #   integration = website.integration_for(:ai)
  #
  #   # Access credentials (decrypted)
  #   api_key = integration.credential(:api_key)
  #
  #   # Access settings
  #   model = integration.setting(:default_model)
  #
  #   # Test connection
  #   if integration.test_connection
  #     puts "Connected!"
  #   end
# == Schema Information
#
# Table name: pwb_website_integrations
# Database name: primary
#
#  id                 :bigint           not null, primary key
#  category           :string           not null
#  credentials        :text
#  enabled            :boolean          default(TRUE)
#  last_error_at      :datetime
#  last_error_message :text
#  last_used_at       :datetime
#  provider           :string           not null
#  settings           :jsonb
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  website_id         :bigint           not null
#
# Indexes
#
#  idx_website_integrations_unique_provider                   (website_id,category,provider) UNIQUE
#  index_pwb_website_integrations_on_website_id               (website_id)
#  index_pwb_website_integrations_on_website_id_and_category  (website_id,category)
#  index_pwb_website_integrations_on_website_id_and_enabled   (website_id,enabled)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
  #
  class WebsiteIntegration < ApplicationRecord
    self.table_name = 'pwb_website_integrations'

    # Encrypt credentials at rest
    encrypts :credentials

    # Associations
    belongs_to :website

    # Serialize credentials as JSON (after decryption)
    serialize :credentials, coder: JSON

    # Available integration categories
    CATEGORIES = {
      ai: {
        name: 'Artificial Intelligence',
        description: 'AI-powered content generation and assistance',
        icon: 'sparkles'
      },
      crm: {
        name: 'CRM',
        description: 'Customer relationship management',
        icon: 'users'
      },
      email_marketing: {
        name: 'Email Marketing',
        description: 'Email campaigns and automation',
        icon: 'mail'
      },
      analytics: {
        name: 'Analytics',
        description: 'Website and business analytics',
        icon: 'chart-bar'
      },
      payment: {
        name: 'Payments',
        description: 'Payment processing',
        icon: 'credit-card'
      },
      maps: {
        name: 'Maps',
        description: 'Mapping and geocoding services',
        icon: 'map'
      },
      storage: {
        name: 'Storage',
        description: 'File and media storage',
        icon: 'cloud'
      },
      communication: {
        name: 'Communication',
        description: 'Messaging and notifications',
        icon: 'message-circle'
      }
    }.freeze

    # Validations
    validates :category, presence: true, inclusion: { in: CATEGORIES.keys.map(&:to_s) }
    validates :provider, presence: true
    validates :provider, uniqueness: { scope: [:website_id, :category], message: 'already configured for this category' }

    # Scopes
    scope :enabled, -> { where(enabled: true) }
    scope :disabled, -> { where(enabled: false) }
    scope :for_category, ->(cat) { where(category: cat.to_s) }
    scope :by_provider, ->(provider) { where(provider: provider.to_s) }
    scope :recently_used, -> { where.not(last_used_at: nil).order(last_used_at: :desc) }
    scope :with_errors, -> { where.not(last_error_at: nil) }

    # Class methods
    class << self
      def category_info(category)
        CATEGORIES[category.to_sym]
      end

      def category_names
        CATEGORIES.transform_values { |v| v[:name] }
      end
    end

    # Credential accessors with nil safety
    def credential(key)
      credentials&.dig(key.to_s)
    end

    def set_credential(key, value)
      self.credentials ||= {}
      self.credentials[key.to_s] = value
    end

    def credentials_present?
      credentials.present? && credentials.values.any?(&:present?)
    end

    # Setting accessors with defaults from provider definition
    def setting(key)
      value = settings&.dig(key.to_s)
      return value if value.present?

      # Fall back to provider default
      provider_definition&.default_for(key)
    end

    def set_setting(key, value)
      self.settings ||= {}
      self.settings[key.to_s] = value
    end

    # Provider definition lookup
    def provider_definition
      Integrations::Registry.provider(category, provider)
    end

    # Connection testing
    def test_connection
      definition = provider_definition
      return false unless definition

      instance = definition.new(self)
      result = instance.validate_connection

      if result
        clear_error!
      else
        record_error!(instance.errors.full_messages.join(', '))
      end

      result
    rescue StandardError => e
      record_error!(e.message)
      false
    end

    # Usage tracking
    def record_usage!
      touch(:last_used_at)
    end

    def record_error!(message)
      update_columns(last_error_at: Time.current, last_error_message: message)
    end

    def clear_error!
      update_columns(last_error_at: nil, last_error_message: nil) if last_error_at.present?
    end

    # Status helpers
    def connected?
      enabled? && credentials_present? && last_error_at.nil?
    end

    def has_error?
      last_error_at.present?
    end

    def status
      return :disabled unless enabled?
      return :error if has_error?
      return :not_configured unless credentials_present?

      :connected
    end

    def status_label
      case status
      when :connected then 'Connected'
      when :error then 'Error'
      when :not_configured then 'Not Configured'
      when :disabled then 'Disabled'
      end
    end

    # Display helpers
    def category_name
      CATEGORIES.dig(category.to_sym, :name) || category.titleize
    end

    def provider_name
      provider_definition&.display_name || provider.titleize
    end

    def masked_credential(key)
      value = credential(key)
      return nil unless value.present?

      if value.length <= 8
        '••••••••'
      else
        '••••••••' + value.last(4)
      end
    end
  end
end
