# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API endpoint for updating theme settings
    # Allows clients to change palette selection for the current website
    # Supports cross-theme palettes (any palette can be used with any theme)
    class ThemeSettingsController < BaseController
      # TODO: Consider adding authentication for production use
      # before_action :authenticate_request!, only: [:update_palette]

      # PATCH /api_public/v1/theme_settings/palette
      #
      # Request body:
      # {
      #   "palette_id": "ocean_blue"
      # }
      #
      # Response (success - 200):
      # {
      #   "success": true,
      #   "data": {
      #     "palette_id": "ocean_blue",
      #     "palette_name": "Ocean Blue",
      #     "source_theme": "default",
      #     "website_theme": "brisbane",
      #     "is_recommended": false,
      #     "updated_at": "2026-01-24T12:00:00Z"
      #   }
      # }
      #
      # Response (error - 422):
      # {
      #   "success": false,
      #   "error": "Palette not found"
      # }
      def update_palette
        palette_id = params[:palette_id].to_s.presence
        website = Pwb::Current.website
        palette_loader = Pwb::PaletteLoader.new

        # Validate required parameters
        unless palette_id.present?
          return render json: {
            success: false,
            error: "Missing required parameter: palette_id"
          }, status: :bad_request
        end

        # Find palette globally (supports cross-theme palettes)
        palette_info = palette_loader.find_palette_globally(palette_id)
        unless palette_info
          return render json: {
            success: false,
            error: "Palette '#{palette_id}' not found"
          }, status: :not_found
        end

        source_theme = palette_info[:theme_name]
        palette_data = palette_info[:palette]

        # Apply the palette using existing model method (now supports cross-theme)
        if website.apply_palette!(palette_id)
          # Check if this palette is "recommended" for the website's current theme
          is_recommended = website.theme_name == source_theme

          render json: {
            success: true,
            data: {
              palette_id: palette_id,
              palette_name: palette_data["name"],
              source_theme: source_theme,
              website_theme: website.theme_name,
              is_recommended: is_recommended,
              updated_at: website.reload.updated_at.iso8601
            }
          }
        else
          render json: {
            success: false,
            error: "Failed to update palette"
          }, status: :unprocessable_content
        end
      rescue StandardError => e
        Rails.logger.error("[API ThemeSettings] Error updating palette: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
        render json: {
          success: false,
          error: "An unexpected error occurred"
        }, status: :internal_server_error
      end
    end
  end
end
