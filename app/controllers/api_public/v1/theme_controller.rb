# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API endpoint for theme configuration
    # Returns complete theme data including colors, fonts, and CSS
    class ThemeController < BaseController
      include ApiPublic::Cacheable

      # GET /api_public/v1/theme
      # Returns theme configuration for the current website
      #
      # Query Parameters:
      # - locale: optional locale code (e.g., "en", "es")
      #
      # Response:
      # {
      #   "theme": {
      #     "name": "brisbane",
      #     "palette_id": "ocean_blue",
      #     "colors": {
      #       "primary_color": "#3B82F6",
      #       "secondary_color": "#10B981",
      #       ...
      #     },
      #     "fonts": {
      #       "heading": "Playfair Display",
      #       "body": "Inter"
      #     },
      #     "dark_mode": {
      #       "enabled": true,
      #       "setting": "auto"
      #     },
      #     "css_variables": ":root { --primary-color: #3B82F6; ... }"
      #   }
      # }
      def index
        locale = params[:locale]
        I18n.locale = locale if locale.present?

        website = Pwb::Current.website
        palette_id = params[:palette_id].presence

        # Cache theme for 1 hour - changes infrequently
        etag_data = [website.id, website.updated_at, website.style_variables, palette_id]
        set_long_cache(max_age: 1.hour, etag_data: etag_data)
        return if performed?

        render json: {
          theme: build_theme_response(website, palette_id: palette_id)
        }
      end

      private

      def build_theme_response(website, palette_id: nil)
        theme = website.current_theme
        palette_override = palette_id.present? && theme&.valid_palette?(palette_id) ? palette_id : nil
        base_vars = website.style_variables_for_theme&.dig("default") ||
          Pwb::WebsiteStyleable::DEFAULT_STYLE_VARIABLES.dup
        palette_colors = palette_override ? theme.palette_colors(palette_override) : nil
        colors = palette_colors.present? ? base_vars.merge(palette_colors) : website.style_variables
        css_variables = if palette_override && theme
          website.palette_loader.generate_full_css(theme.name, palette_override)
        else
          website.css_variables_with_dark_mode
        end

        {
          name: website.theme_name || "default",
          palette_id: palette_override || website.effective_palette_id,
          palette_mode: website.respond_to?(:palette_mode) ? (website.palette_mode || "dynamic") : "dynamic",
          colors: colors,
          fonts: extract_fonts(website),
          border_radius: extract_border_radius(website),
          dark_mode: build_dark_mode_config(website),
          css_variables: css_variables,
          custom_css: website.respond_to?(:raw_css) ? website.raw_css : nil,
          map_config: build_map_config(website)
        }
      end

      def extract_fonts(website)
        vars = website.style_variables
        {
          heading: vars["font_primary"] || vars["font_secondary"] || "Inter",
          body: vars["font_primary"] || "Inter"
        }
      end

      def extract_border_radius(website)
        vars = website.style_variables
        base_radius = vars["border_radius"] || "0.5rem"

        {
          sm: "calc(#{base_radius} * 0.5)",
          md: base_radius,
          lg: "calc(#{base_radius} * 1.5)",
          xl: "calc(#{base_radius} * 2)"
        }
      end

      def build_dark_mode_config(website)
        {
          enabled: website.dark_mode_enabled?,
          setting: website.dark_mode_setting,
          force_dark: website.force_dark_mode?,
          auto: website.auto_dark_mode?
        }
      end

      def build_map_config(website)
        {
          tile_url: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          attribution: "&copy; OpenStreetMap contributors",
          default_zoom: 13,
          max_zoom: 18,
          scroll_wheel_zoom: false,
          default_center: default_map_center(website)
        }
      end

      def default_map_center(website)
        # Try to get from website settings, otherwise use sensible default
        if website.respond_to?(:default_map_center) && website.default_map_center.present?
          website.default_map_center
        elsif website.respond_to?(:latitude) && website.latitude.present?
          { lat: website.latitude, lng: website.longitude }
        else
          # Default to central Europe
          { lat: 40.4168, lng: -3.7038 }
        end
      end
    end
  end
end
