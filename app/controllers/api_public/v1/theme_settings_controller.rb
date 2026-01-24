# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API endpoint for updating theme settings
    # Allows clients to change palette selection for the current website
    # Supports cross-theme palettes (any palette can be used with any theme)
    # Supports custom palettes (provide full palette definition if palette_id doesn't exist)
    class ThemeSettingsController < BaseController
      # TODO: Consider adding authentication for production use
      # before_action :authenticate_request!, only: [:update_palette]

      # PATCH /api_public/v1/theme_settings/palette
      #
      # Request body (existing palette):
      # {
      #   "palette_id": "ocean_blue"
      # }
      #
      # Request body (custom palette):
      # {
      #   "palette_id": "eco_green",
      #   "palette": {
      #     "id": "eco_green",
      #     "name": "Eco Green",
      #     "colors": {
      #       "primary_color": "#10B981",
      #       "secondary_color": "#1F2937",
      #       ...
      #     }
      #   }
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
      #     "is_custom": false,
      #     "updated_at": "2026-01-24T12:00:00Z"
      #   }
      # }
      def update_palette
        palette_id = params[:palette_id].to_s.presence
        custom_palette = params[:palette]
        website = Pwb::Current.website
        palette_loader = Pwb::PaletteLoader.new

        # Validate required parameters
        unless palette_id.present?
          return render json: {
            success: false,
            error: "Missing required parameter: palette_id"
          }, status: :bad_request
        end

        # Try to find palette globally (supports cross-theme palettes)
        palette_info = palette_loader.find_palette_globally(palette_id)

        if palette_info
          # Existing palette found - apply it
          apply_existing_palette(website, palette_id, palette_info)
        elsif custom_palette.present? && custom_palette[:colors].present?
          # Custom palette provided - apply it
          apply_custom_palette(website, palette_id, custom_palette)
        else
          # Neither found nor provided
          render json: {
            success: false,
            error: "Palette '#{palette_id}' not found. Provide a 'palette' object with 'colors' to create a custom palette."
          }, status: :not_found
        end
      rescue StandardError => e
        Rails.logger.error("[API ThemeSettings] Error updating palette: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
        render json: {
          success: false,
          error: "An unexpected error occurred"
        }, status: :internal_server_error
      end

      private

      def apply_existing_palette(website, palette_id, palette_info)
        source_theme = palette_info[:theme_name]
        palette_data = palette_info[:palette]

        if website.apply_palette!(palette_id)
          is_recommended = website.theme_name == source_theme

          render json: {
            success: true,
            data: {
              palette_id: palette_id,
              palette_name: palette_data["name"],
              source_theme: source_theme,
              website_theme: website.theme_name,
              is_recommended: is_recommended,
              is_custom: false,
              updated_at: website.reload.updated_at.iso8601
            }
          }
        else
          render json: {
            success: false,
            error: "Failed to update palette"
          }, status: :unprocessable_content
        end
      end

      def apply_custom_palette(website, palette_id, custom_palette)
        colors = extract_palette_colors(custom_palette)
        palette_name = custom_palette[:name] || custom_palette["name"] || palette_id.titleize

        # Validate minimum required colors
        unless colors["primary_color"].present?
          return render json: {
            success: false,
            error: "Custom palette must include at least 'primary_color'"
          }, status: :unprocessable_content
        end

        if website.apply_custom_palette!(palette_id, colors)
          render json: {
            success: true,
            data: {
              palette_id: palette_id,
              palette_name: palette_name,
              source_theme: nil,
              website_theme: website.theme_name,
              is_recommended: false,
              is_custom: true,
              updated_at: website.reload.updated_at.iso8601
            }
          }
        else
          render json: {
            success: false,
            error: "Failed to apply custom palette"
          }, status: :unprocessable_content
        end
      end

      def extract_palette_colors(palette_data)
        colors = palette_data[:colors] || palette_data["colors"] || {}

        # Convert ActionController::Parameters to hash if needed
        # This is necessary because Rails 8.x won't allow merging unpermitted params
        colors = colors.to_unsafe_h if colors.respond_to?(:to_unsafe_h)

        # Normalize to string keys
        colors.transform_keys(&:to_s)
      end
    end
  end
end
