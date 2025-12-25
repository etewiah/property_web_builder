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

    # Get style variables for the current theme
    # If a palette is selected, merge palette colors into style variables
    def style_variables
      base_vars = style_variables_for_theme["default"] || DEFAULT_STYLE_VARIABLES.dup

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
  end
end
