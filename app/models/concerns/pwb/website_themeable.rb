# frozen_string_literal: true

module Pwb
  # Concern for managing theme availability on websites.
  #
  # Provides methods to determine which themes are available for a website,
  # based on:
  # 1. Website-specific available_themes (if set)
  # 2. Tenant default themes (from TenantSettings)
  # 3. The "default" theme is always available
  #
  # Usage:
  #   website.accessible_themes         # => [Theme, Theme, ...]
  #   website.theme_accessible?('bologna')  # => true/false
  #   website.accessible_theme_names    # => ['default', 'brisbane']
  #
  module WebsiteThemeable
    extend ActiveSupport::Concern

    # The default theme name - always available
    DEFAULT_THEME = 'default'.freeze

    included do
      # Validate that theme_name is accessible to this website
      validate :theme_must_be_accessible, if: :theme_name_changed?
    end

    # Get all themes accessible to this website
    # Returns enabled themes filtered by website/tenant availability
    #
    # @return [Array<Theme>]
    #
    def accessible_themes
      theme_names = accessible_theme_names
      Theme.enabled.select { |theme| theme_names.include?(theme.name) }
    end

    # Get names of themes accessible to this website
    # Uses website-specific list if set, otherwise tenant defaults
    #
    # @return [Array<String>]
    #
    def accessible_theme_names
      themes = if available_themes.present?
                 available_themes
               else
                 TenantSettings.instance.effective_default_themes
               end

      # Always include default theme and ensure uniqueness
      ([DEFAULT_THEME] + themes).uniq
    end

    # Check if a specific theme is accessible to this website
    #
    # @param theme_name [String] The theme name to check
    # @return [Boolean]
    #
    def theme_accessible?(theme_name)
      return true if theme_name.to_s == DEFAULT_THEME

      accessible_theme_names.include?(theme_name.to_s)
    end

    # Check if this website has custom theme availability set
    #
    # @return [Boolean]
    #
    def custom_theme_availability?
      available_themes.present?
    end

    # Update the available themes for this website
    #
    # @param themes [Array<String>] Array of theme names
    # @return [Boolean] true if saved successfully
    #
    def update_available_themes(themes)
      update(available_themes: Array(themes).reject(&:blank?))
    end

    # Reset to use tenant default themes
    #
    # @return [Boolean] true if saved successfully
    #
    def reset_to_default_themes
      update(available_themes: nil)
    end

    private

    def theme_must_be_accessible
      return if theme_name.blank?
      return if theme_accessible?(theme_name)

      errors.add(:theme_name, "is not available for this website")
    end
  end
end
