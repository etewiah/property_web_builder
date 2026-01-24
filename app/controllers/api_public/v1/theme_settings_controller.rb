# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API endpoint for updating theme settings
    # Allows clients to change palette selection for the current website
    class ThemeSettingsController < BaseController
      # TODO: Consider adding authentication for production use
      # before_action :authenticate_request!, only: [:update_palette]

      # PATCH /api_public/v1/theme_settings/palette
      #
      # Request body:
      # {
      #   "theme_name": "brisbane",
      #   "palette_id": "ocean_blue"
      # }
      #
      # Response (success - 200):
      # {
      #   "success": true,
      #   "data": {
      #     "theme_name": "brisbane",
      #     "palette_id": "ocean_blue",
      #     "updated_at": "2026-01-24T12:00:00Z"
      #   }
      # }
      #
      # Response (error - 422):
      # {
      #   "success": false,
      #   "error": "Invalid palette_id for theme"
      # }
      def update_palette
        theme_name = params[:theme_name].to_s.presence
        palette_id = params[:palette_id].to_s.presence
        website = Pwb::Current.website

        # Validate required parameters
        unless theme_name.present? && palette_id.present?
          return render json: {
            success: false,
            error: "Missing required parameters: theme_name and palette_id"
          }, status: :bad_request
        end

        # Find and validate theme
        theme = Pwb::Theme.find_by(name: theme_name)
        unless theme
          return render json: {
            success: false,
            error: "Theme '#{theme_name}' not found"
          }, status: :not_found
        end

        # Validate palette exists for the theme
        unless theme.valid_palette?(palette_id)
          return render json: {
            success: false,
            error: "Invalid palette_id '#{palette_id}' for theme '#{theme_name}'"
          }, status: :unprocessable_content
        end

        # Optionally verify the website is using this theme
        if website.theme_name != theme_name
          return render json: {
            success: false,
            error: "Website is not using theme '#{theme_name}'. Current theme: '#{website.theme_name}'"
          }, status: :unprocessable_content
        end

        # Apply the palette using existing model method
        if website.apply_palette!(palette_id)
          render json: {
            success: true,
            data: {
              theme_name: theme_name,
              palette_id: palette_id,
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
