# frozen_string_literal: true

# Website::Styleable
#
# Manages theme styling, CSS variables, and visual configuration.
# Provides methods for style variable access and preset style application.
#
# Palette Modes:
# - "dynamic": CSS variables set at runtime (default, allows live experimentation)
# - "compiled": Pre-generated CSS with baked-in hex values (maximum performance)
#
module Pwb
  module WebsiteStyleable
    extend ActiveSupport::Concern

    PALETTE_MODES = %w[dynamic compiled].freeze

    included do
      # Clear memoized theme data when theme_name changes
      before_save :clear_theme_cache, if: :theme_name_changed?
      after_save :clear_palette_loader_cache, if: :saved_change_to_selected_palette?

      # Set default palette when theme changes or on creation
      before_save :ensure_palette_selected, if: :should_set_default_palette?

      # Validate palette_mode if the column exists
      validates :palette_mode, inclusion: { in: PALETTE_MODES }, allow_nil: true, if: -> { respond_to?(:palette_mode) }
    end

    DEFAULT_STYLE_VARIABLES = {
      "primary_color" => "#e91b23",
      "secondary_color" => "#3498db",
      "action_color" => "#e91b23",  # Default to primary_color for CTA buttons
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
    # Falls back to 'default' theme if theme_name is blank
    def current_theme
      @current_theme ||= begin
        name = theme_name.presence || "default"
        Pwb::Theme.find_by(name: name)
      end
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

      palette_loader.get_dark_colors(current_theme.name, effective_palette_id)
    end

    # Get CSS variables with dark mode support
    # Returns full CSS with :root, @media (prefers-color-scheme: dark), and .dark class
    def css_variables_with_dark_mode
      return css_variables unless dark_mode_enabled?

      return "" unless current_theme && effective_palette_id

      palette_loader.generate_full_css(current_theme.name, effective_palette_id)
    end

    # Get light mode only CSS variables
    def css_variables
      return "" unless current_theme && effective_palette_id

      palette_loader.generate_css_variables(current_theme.name, effective_palette_id)
    end

    # Check if current palette has explicit dark mode colors
    def palette_has_explicit_dark_mode?
      return false unless current_theme && effective_palette_id

      palette = palette_loader.get_palette(current_theme.name, effective_palette_id)
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

    # Force refresh of theme data (useful after theme changes)
    def refresh_theme_data!
      clear_theme_cache
      clear_palette_loader_cache
      current_theme # Re-memoize
    end

    # ===================
    # Palette Mode Support
    # ===================

    # Check if palette is in dynamic mode (CSS variables set at runtime)
    def palette_dynamic?
      !respond_to?(:palette_mode) || palette_mode.blank? || palette_mode == "dynamic"
    end

    # Check if palette is in compiled mode (pre-generated static CSS)
    def palette_compiled?
      respond_to?(:palette_mode) && palette_mode == "compiled"
    end

    # Compile the current palette into static CSS for production performance
    # This generates CSS with actual hex values baked in (no CSS variables)
    #
    # @return [Boolean] true if compilation was successful
    def compile_palette!
      return false unless respond_to?(:palette_mode)

      compiler = PaletteCompiler.new(self)
      css = compiler.compile

      update!(
        palette_mode: "compiled",
        compiled_palette_css: css,
        palette_compiled_at: Time.current
      )

      true
    rescue StandardError => e
      Rails.logger.error("Palette compilation failed for website #{id}: #{e.message}")
      false
    end

    # Revert to dynamic mode (CSS variables set at runtime)
    # This allows live experimentation with colors again
    #
    # @return [Boolean] true if unpin was successful
    def unpin_palette!
      return true unless respond_to?(:palette_mode)

      update!(
        palette_mode: "dynamic",
        compiled_palette_css: nil,
        palette_compiled_at: nil
      )

      true
    end

    # Check if compiled palette is stale (style_variables changed after compilation)
    # @return [Boolean] true if palette needs recompilation
    def palette_stale?
      return false unless palette_compiled?
      return true if compiled_palette_css.blank?
      return true if palette_compiled_at.blank?

      # Check if record was updated after compilation
      # Note: Use 1-second threshold to handle same-transaction updates
      # where palette_compiled_at and updated_at differ by microseconds
      (updated_at - palette_compiled_at) > 1.second
    end

    # Get CSS for the current palette mode
    # In compiled mode, returns pre-generated CSS
    # In dynamic mode, returns CSS variable declarations
    #
    # @return [String] CSS string
    def palette_css
      if palette_compiled? && compiled_palette_css.present?
        compiled_palette_css
      else
        generate_dynamic_palette_css
      end
    end

    # Generate dynamic CSS with CSS variables
    # This is used in dynamic mode for live color changes
    #
    # @return [String] CSS with variable declarations
    def generate_dynamic_palette_css
      vars = style_variables
      return "" if vars.blank?

      css_lines = []
      css_lines << ":root {"

      # Primary color and shades
      primary = vars["primary_color"] || "#3b82f6"
      css_lines << "  --pwb-primary-color: #{primary};"
      css_lines << "  --primary-color: #{primary};"
      css_lines << generate_shade_variables("primary", primary)

      # Secondary color and shades
      secondary = vars["secondary_color"] || "#64748b"
      css_lines << "  --pwb-secondary-color: #{secondary};"
      css_lines << "  --secondary-color: #{secondary};"
      css_lines << generate_shade_variables("secondary", secondary)

      # Accent color and shades
      accent = vars["accent_color"] || "#f59e0b"
      css_lines << "  --pwb-accent-color: #{accent};"
      css_lines << "  --accent-color: #{accent};"
      css_lines << generate_shade_variables("accent", accent)

      # Additional palette colors
      additional_color_keys.each do |key|
        value = vars[key]
        next unless value.present?

        css_key = key.gsub("_", "-")
        css_lines << "  --pwb-#{css_key}: #{value};"
        css_lines << "  --#{css_key}: #{value};"
      end

      css_lines << "}"
      css_lines.join("\n")
    end

    # Get palette mode options for admin UI select
    def self.palette_mode_options
      [
        ["Dynamic (live experimentation)", "dynamic"],
        ["Compiled (production performance)", "compiled"]
      ]
    end

    private

    def palette_loader
      @palette_loader ||= PaletteLoader.new
    end

    # Check if we should set a default palette
    # Returns true if:
    # - selected_palette is blank AND
    # - theme_name is present AND
    # - either this is a new record OR theme_name has changed
    def should_set_default_palette?
      selected_palette.blank? && theme_name.present? && (new_record? || theme_name_changed?)
    end

    # Set the default palette from the current theme
    def ensure_palette_selected
      return unless current_theme

      default_palette = current_theme.default_palette_id
      self.selected_palette = default_palette if default_palette.present?
    end

    # Clear memoized theme when theme_name changes
    def clear_theme_cache
      @current_theme = nil
    end

    # Clear palette loader cache to force re-read from files
    def clear_palette_loader_cache
      @palette_loader&.clear_cache!
      @palette_loader = nil
    end

    # Generate CSS variable declarations for color shades using color-mix
    def generate_shade_variables(name, base_color)
      shades = []
      # Light shades (mixing with white)
      shades << "  --pwb-#{name}-50: color-mix(in srgb, #{base_color} 10%, white);"
      shades << "  --pwb-#{name}-100: color-mix(in srgb, #{base_color} 20%, white);"
      shades << "  --pwb-#{name}-200: color-mix(in srgb, #{base_color} 35%, white);"
      shades << "  --pwb-#{name}-300: color-mix(in srgb, #{base_color} 50%, white);"
      shades << "  --pwb-#{name}-400: color-mix(in srgb, #{base_color} 70%, white);"
      shades << "  --pwb-#{name}-500: #{base_color};"
      # Dark shades (mixing with black)
      shades << "  --pwb-#{name}-600: color-mix(in srgb, #{base_color} 85%, black);"
      shades << "  --pwb-#{name}-700: color-mix(in srgb, #{base_color} 70%, black);"
      shades << "  --pwb-#{name}-800: color-mix(in srgb, #{base_color} 55%, black);"
      shades << "  --pwb-#{name}-900: color-mix(in srgb, #{base_color} 40%, black);"
      shades.join("\n")
    end

    # Keys for additional palette colors beyond primary/secondary/accent
    def additional_color_keys
      %w[
        background_color text_color
        header_background_color header_text_color
        footer_background_color footer_text_color
        card_background_color border_color
        link_color success_color warning_color error_color
      ]
    end
  end
end
