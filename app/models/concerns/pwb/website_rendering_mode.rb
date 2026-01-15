# frozen_string_literal: true

# Concern for managing website rendering modes
# Websites can use either Rails (B themes) or Client (A themes) rendering
#
# Key behaviors:
# - rendering_mode defaults to 'rails'
# - client_theme_name is required when using 'client' mode
# - rendering_mode becomes immutable after website has content
#
module Pwb
  module WebsiteRenderingMode
    extend ActiveSupport::Concern

    RENDERING_MODES = %w[rails client].freeze

    included do
      # ===================
      # Validations
      # ===================
      validates :rendering_mode, inclusion: { in: RENDERING_MODES }
      validates :client_theme_name, presence: true, if: :client_rendering?
      validate :client_theme_must_exist, if: :client_rendering?
      validate :rendering_mode_immutable, on: :update
    end

    # ===================
    # Instance Methods
    # ===================

    # Check if using Rails rendering (B themes)
    #
    # @return [Boolean]
    def rails_rendering?
      rendering_mode == 'rails'
    end

    # Check if using client rendering (A themes)
    #
    # @return [Boolean]
    def client_rendering?
      rendering_mode == 'client'
    end

    # Get the client theme object
    #
    # @return [Pwb::ClientTheme, nil]
    def client_theme
      return nil unless client_rendering?

      @client_theme ||= Pwb::ClientTheme.enabled.by_name(client_theme_name)
    end

    # Get merged theme config (defaults + website overrides)
    #
    # @return [Hash]
    def effective_client_theme_config
      return {} unless client_theme

      client_theme.config_for_website(self)
    end

    # Generate CSS variables for client theme
    #
    # @return [String]
    def client_theme_css_variables
      return '' unless client_theme

      client_theme.generate_css_variables(effective_client_theme_config)
    end

    # Check if rendering mode can still be changed
    # Locked after website has been provisioned and has content
    #
    # @return [Boolean]
    def rendering_mode_locked?
      provisioning_completed_at.present? && page_contents.any?
    end

    # Check if rendering mode can be changed
    #
    # @return [Boolean]
    def rendering_mode_changeable?
      !rendering_mode_locked?
    end

    private

    # Validate that the client theme exists and is enabled
    def client_theme_must_exist
      return unless client_theme_name.present?

      unless Pwb::ClientTheme.enabled.exists?(name: client_theme_name)
        errors.add(:client_theme_name, 'is not a valid client theme')
      end
    end

    # Prevent changing rendering_mode after content is created
    def rendering_mode_immutable
      return unless rendering_mode_changed?
      return unless rendering_mode_locked?

      errors.add(:rendering_mode, 'cannot be changed after website has content')
    end
  end
end
