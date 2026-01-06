# frozen_string_literal: true

module Pwb
  # TenantSettings is a singleton model for tenant-wide configuration.
  # Only one record should exist, accessed via TenantSettings.instance
  #
  # Usage:
  #   Pwb::TenantSettings.instance.default_available_themes
  #   Pwb::TenantSettings.default_themes
  #
# == Schema Information
#
# Table name: pwb_tenant_settings
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  configuration            :jsonb
#  default_available_themes :text             default([]), is an Array
#  singleton_key            :string           default("default"), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_pwb_tenant_settings_on_singleton_key  (singleton_key) UNIQUE
#
  class TenantSettings < ApplicationRecord
    self.table_name = 'pwb_tenant_settings'

    # Ensure only one record exists
    validates :singleton_key, uniqueness: true

    # Default theme is always available
    DEFAULT_THEME = 'default'.freeze

    class << self
      # Get the singleton instance, creating it if needed
      #
      # @return [TenantSettings]
      #
      def instance
        find_or_create_by!(singleton_key: 'default')
      end

      # Shorthand to get default available themes
      #
      # @return [Array<String>]
      #
      def default_themes
        instance.default_available_themes || []
      end

      # Update default available themes
      #
      # @param themes [Array<String>] Array of theme names
      # @return [Boolean] true if saved successfully
      #
      def update_default_themes(themes)
        instance.update(default_available_themes: Array(themes).reject(&:blank?))
      end
    end

    # Get themes that are available by default
    # Always includes the default theme
    #
    # @return [Array<String>]
    #
    def effective_default_themes
      themes = default_available_themes || []
      themes = [DEFAULT_THEME] if themes.empty?
      themes.uniq
    end

    # Check if a theme is available by default
    #
    # @param theme_name [String] Theme name to check
    # @return [Boolean]
    #
    def theme_available?(theme_name)
      effective_default_themes.include?(theme_name.to_s)
    end
  end
end
