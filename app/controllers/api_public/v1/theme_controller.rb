# frozen_string_literal: true

module ApiPublic
  module V1
    # ThemeController provides theming configuration for headless frontends
    # Returns CSS variables, colors, and fonts for dynamic theme injection
    class ThemeController < BaseController
      def index
        website = Pwb::Current.website

        render json: {
          data: {
            theme_name: website.theme_name,
            dark_mode: website.dark_mode_setting,
            colors: website.style_variables,
            css_variables: website.css_variables,
            css_with_dark_mode: website.css_variables_with_dark_mode,
            fonts: extract_fonts(website),
            palette: {
              selected: website.selected_palette,
              available: website.available_palettes.keys
            }
          }
        }
      end

      private

      def extract_fonts(website)
        vars = website.style_variables || {}
        {
          primary: vars["font_primary"] || "Open Sans",
          secondary: vars["font_secondary"] || "Vollkorn"
        }
      end
    end
  end
end
