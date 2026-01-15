# frozen_string_literal: true

module ApiPublic
  module V1
    class AllThemesController < BaseController
      # GET /api_public/v1/all-themes
      def index
        themes = Pwb::Theme.enabled.map do |theme|
          {
            name: theme.name,
            description: theme.description,
            # Generate CSS variables for the default palette (no ID passed)
            css_variables: theme.generate_palette_css,
            palettes: theme.palettes.map do |id, config|
              {
                id: id,
                name: config["name"],
                colors: theme.palette_colors(id)
              }
            end
          }
        end

        render json: {
          meta: {
            total: themes.count,
            version: "1.0"
          },
          data: themes
        }
      end
    end
  end
end
