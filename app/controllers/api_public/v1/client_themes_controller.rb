# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API for client themes (A themes for Astro rendering)
    # Used by Astro client to list and retrieve theme configurations
    class ClientThemesController < BaseController
      # GET /api_public/v1/client-themes
      # Returns all enabled client themes
      def index
        themes = Pwb::ClientTheme.enabled.order(:friendly_name)

        render json: {
          meta: {
            total: themes.count,
            version: '1.0'
          },
          data: themes.map(&:as_api_json)
        }
      end

      # GET /api_public/v1/client-themes/:name
      # Returns a specific client theme with full configuration
      def show
        theme = Pwb::ClientTheme.enabled.find_by!(name: params[:name])

        render json: {
          data: theme.as_api_json
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Theme not found' }, status: :not_found
      end
    end
  end
end
