# frozen_string_literal: true

# Website::Styleable
#
# Manages theme styling, CSS variables, and visual configuration.
# Provides methods for style variable access and preset style application.
#
module Pwb
  module WebsiteStyleable
    extend ActiveSupport::Concern

    DEFAULT_STYLE_VARIABLES = {
      "primary_color" => "#e91b23",
      "secondary_color" => "#3498db",
      "action_color" => "green",
      "body_style" => "siteLayout.wide",
      "theme" => "light",
      "font_primary" => "Open Sans",
      "font_secondary" => "Vollkorn",
      "border_radius" => "0.5rem",
      "container_padding" => "1rem"
    }.freeze

    # Dark mode setting options
    DARK_MODE_SETTINGS = {
      light_only: "light_only", # Only light mode, no dark CSS
      auto: "auto",             # Respects user's system preference
      dark: "dark"              # Forces dark mode
    }.freeze

    # Get style variables for the current theme
    # If a palette is selected, merge palette colors into style variables
    def style_variables
      base_vars = style_variables_for_theme&.dig("default") || DEFAULT_STYLE_VARIABLES.dup

      # Apply palette colors if a palette is selected
      if selected_palette.present? && current_theme
        palette_colors = current_theme.palette_colors(selected_palette)
        palette_colors.present? ? base_vars.merge(palette_colors) : base_vars
      else
        base_vars
      end
    end

    # Get the current theme object
    def current_theme
      @current_theme ||= Pwb::Theme.find_by(name: theme_name)
    end

    # Get effective palette ID (selected or theme default)
    def effective_palette_id
      return selected_palette if selected_palette.present? && current_theme&.valid_palette?(selected_palette)

      current_theme&.default_palette_id
    end

    # Apply a palette to the website
    # This updates both the selected_palette and merges colors into style_variables
    def apply_palette!(palette_id)
      return false unless current_theme&.valid_palette?(palette_id)

      update(selected_palette: palette_id)
    end

    # Get available palettes for the current theme
    def available_palettes
      current_theme&.palettes || {}
    end

    # Get palette options for form selects
    def palette_options_for_select
      current_theme&.palette_options || []
    end

    # Set style variables for the current theme
    def style_variables=(style_variables)
      style_variables_for_theme["default"] = style_variables
    end

    # Get element class for styling
    def get_element_class(element_name)
      style_details = style_variables_for_theme["default"] || Pwb::PresetStyle.default_values
      style_associations = style_details["associations"] || []
      style_associations[element_name] || ""
    end

    # Get style variable value
    def get_style_var(var_name)
      style_details = style_variables_for_theme["default"] || Pwb::PresetStyle.default_values
      style_vars = style_details["variables"] || []
      style_vars[var_name] || ""
    end

    # Bulk set styles from admin UI
    def style_settings=(style_settings)
      style_variables_for_theme["default"] = style_settings
    end

    # Set styles from a preset configuration
    def style_settings_from_preset=(preset_style_name)
      preset_style = Pwb::PresetStyle.where(name: preset_style_name).first
      if preset_style
        style_variables_for_theme["default"] = preset_style.attributes.as_json
      end
    end

    # Get body style class
    def body_style
      if style_variables_for_theme["default"] && (style_variables_for_theme["default"]["body_style"] == "siteLayout.boxed")
        "body-boxed"
      else
        ""
      end
    end

    # Get logo URL from content photos
    def logo_url
      logo_content = contents.find_by_key("logo")
      if logo_content && !logo_content.content_photos.empty?
        logo_content.content_photos.first.image_url
      end
    end

    # Set theme name with validation
    def theme_name=(theme_name_value)
      theme_with_name_exists = Pwb::Theme.where(name: theme_name_value).count > 0
      if theme_with_name_exists
        write_attribute(:theme_name, theme_name_value)
      end
    end

    # Check if Google Analytics should render
    def render_google_analytics
      Rails.env.production? && analytics_id.present?
    end

    # ===================
    # Dark Mode Support
    # ===================

    # Check if dark mode is enabled for this website
    # Returns true for 'auto' or 'dark' settings
    def dark_mode_enabled?
      %w[auto dark].include?(dark_mode_setting)
    end

    # Check if dark mode should be forced (no system preference)
    def force_dark_mode?
      dark_mode_setting == "dark"
    end

    # Check if dark mode respects system preference
    def auto_dark_mode?
      dark_mode_setting == "auto"
    end

    # Get HTML class for dark mode
    # Returns 'pwb-dark' for forced dark mode, nil otherwise
    def dark_mode_html_class
      force_dark_mode? ? "pwb-dark" : nil
    end

    # Get dark mode colors for the current palette
    def dark_mode_colors
      return {} unless dark_mode_enabled? && current_theme && effective_palette_id

      palette_loader.get_dark_colors(theme_name, effective_palette_id)
    end

    # Get CSS variables with dark mode support
    # Returns full CSS with :root, @media (prefers-color-scheme: dark), and .dark class
    def css_variables_with_dark_mode
      return css_variables unless dark_mode_enabled?

      return "" unless current_theme && effective_palette_id

      palette_loader.generate_full_css(theme_name, effective_palette_id)
    end

    # Get light mode only CSS variables
    def css_variables
      return "" unless current_theme && effective_palette_id

      palette_loader.generate_css_variables(theme_name, effective_palette_id)
    end

    # Check if current palette has explicit dark mode colors
    def palette_has_explicit_dark_mode?
      return false unless current_theme && effective_palette_id

      palette = palette_loader.get_palette(theme_name, effective_palette_id)
      palette_loader.has_explicit_dark_mode?(palette)
    end

    # Get dark mode setting options for form
    def self.dark_mode_setting_options
      [
        ["Light Only (no dark mode)", "light_only"],
        ["Auto (follow system preference)", "auto"],
        ["Always Dark", "dark"]
      ]
    end

    private

    def palette_loader
      @palette_loader ||= PaletteLoader.new
    end
  end
end
