# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API endpoints for theme palettes
    # Lists available palettes and returns palette details for a theme
    class ThemePalettesController < BaseController
      include ApiPublic::Cacheable

      # GET /api_public/v1/themes/:theme_name/palettes
      def index
        theme = find_theme
        return render_not_found unless theme

        set_long_cache(max_age: 1.hour, etag_data: [theme.name, theme.palettes.keys])
        return if performed?

        render json: {
          theme: theme.name,
          palettes: theme.list_palettes
        }
      end

      # GET /api_public/v1/themes/:theme_name/palettes/:palette_id
      def show
        theme = find_theme
        return render_not_found unless theme

        palette_id = params[:palette_id].to_s
        palette = theme.palette(palette_id)
        return render_palette_not_found unless palette

        set_long_cache(max_age: 1.hour, etag_data: [theme.name, palette_id])
        return if performed?

        render json: {
          theme: theme.name,
          palette: palette.merge(
            "css_variables" => theme.generate_palette_css(palette_id)
          )
        }
      end

      private

      def find_theme
        theme_name = params[:theme_name].to_s
        return nil if theme_name.blank?

        Pwb::Theme.find_by(name: theme_name)
      end

      def render_not_found
        render json: { error: "Theme not found" }, status: :not_found
      end

      def render_palette_not_found
        render json: { error: "Palette not found" }, status: :not_found
      end
    end
  end
end
