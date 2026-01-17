# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API for website client configuration
    # Provides theme configuration and CSS variables for Astro client
    class WebsiteClientConfigController < BaseController
      # GET /api_public/v1/client-config
      # Returns client rendering configuration for the current website
      def show
        unless @current_website&.client_rendering?
          # Return default data with error info
          render json: {
            data: default_data,
            error: {
              message: 'Client rendering not enabled for this website',
              rendering_mode: @current_website&.rendering_mode || 'unknown'
            }
          }, status: :ok
          def show
            # Set a strong cache header for 5 minutes (adjust as needed)
            expires_in 5.minutes, public: true

            unless @current_website&.client_rendering?
              render json: {
                error: 'Client rendering not enabled for this website',
                rendering_mode: @current_website&.rendering_mode || 'unknown'
              }, status: :not_found
              return
            end

            theme = @current_website.client_theme

            render json: {
              data: {
                rendering_mode: @current_website.rendering_mode,
                theme: theme_data(theme),
                config: @current_website.effective_client_theme_config,
                css_variables: @current_website.client_theme_css_variables,
                website: website_data
              }
            }
          end
          }
        }, status: :ok
      end

      # Returns a valid default data structure for the client config response
      def default_data
        {
          rendering_mode: @current_website&.rendering_mode || 'rails',
          theme: nil,
          config: {},
          css_variables: {},
          website: @current_website ? website_data : {}
        }
      end

      private

      def theme_data(theme)
        return nil unless theme

        {
          name: theme.name,
          friendly_name: theme.friendly_name,
          version: theme.version,
          color_schema: theme.color_schema,
          font_schema: theme.font_schema,
          layout_options: theme.layout_options
        }
      end

      def website_data
        {
          id: @current_website.id,
          subdomain: @current_website.subdomain,
          company_display_name: @current_website.company_display_name,
          default_locale: @current_website.default_client_locale,
          supported_locales: @current_website.supported_locales_with_variants
        }
      end
    end
  end
end
