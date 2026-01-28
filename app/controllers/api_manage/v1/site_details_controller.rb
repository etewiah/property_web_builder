# frozen_string_literal: true

module ApiManage
  module V1
    # SiteDetailsController - Website configuration for editor clients
    #
    # Provides site-level configuration and metadata for the Astro.js
    # content editing client. Includes editable settings and field schemas.
    #
    # Endpoints:
    #   GET /api_manage/v1/site_details - Get site configuration
    #   PATCH /api_manage/v1/site_details - Update site settings
    #
    class SiteDetailsController < BaseController
      # GET /api_manage/v1/site_details
      def show
        website = current_website

        unless website
          render json: { error: 'Website not found' }, status: :not_found
          return
        end

        render json: build_site_details_response(website)
      end

      # PATCH /api_manage/v1/site_details
      def update
        website = current_website

        unless website
          render json: { error: 'Website not found' }, status: :not_found
          return
        end

        if website.update(site_params)
          render json: {
            site: build_site_details_response(website),
            message: 'Site settings updated successfully'
          }
        else
          render json: {
            error: 'Validation failed',
            errors: website.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def site_params
        params.require(:site).permit(
          :company_display_name,
          :default_meta_description,
          :default_client_locale,
          :ga4_measurement_id,
          :gtm_container_id,
          :posthog_api_key,
          :posthog_host
        )
      end

      def build_site_details_response(website)
        {
          id: website.id,
          subdomain: website.subdomain,

          # Branding
          branding: build_branding(website),

          # Localization
          localization: build_localization(website),

          # SEO defaults
          seo: build_seo_config(website),

          # Analytics configuration
          analytics: build_analytics_config(website),

          # Navigation structure
          navigation: build_navigation(website),

          # Available pages for editing
          pages: build_pages_summary(website),

          # Theme information
          theme: build_theme_info(website),

          # Field schema for editable settings
          field_schema: build_field_schema,

          # Timestamps
          created_at: website.created_at.iso8601,
          updated_at: website.updated_at.iso8601
        }
      end

      def build_branding(website)
        theme_name = website.theme_name || 'default'
        style_vars = website.style_variables_for_theme&.dig(theme_name) || {}

        {
          company_name: website.company_display_name,
          logo_url: website.main_logo_url,
          favicon_url: website.favicon_url,
          primary_color: style_vars['primary_color'],
          secondary_color: style_vars['secondary_color'],
          accent_color: style_vars['accent_color']
        }.compact
      end

      def build_localization(website)
        available_locales = website.supported_locales || %w[en]
        default_locale = website.default_client_locale || 'en'

        {
          default_locale: default_locale,
          available_locales: available_locales,
          current_locale: I18n.locale.to_s
        }
      end

      def build_seo_config(website)
        {
          default_title: website.company_display_name || website.default_seo_title,
          default_description: website.default_meta_description,
          og_image: website.main_logo_url
        }.compact
      end

      def build_analytics_config(website)
        config = {}

        if website.respond_to?(:ga4_measurement_id) && website.ga4_measurement_id.present?
          config[:ga4_id] = website.ga4_measurement_id
        end

        if website.respond_to?(:gtm_container_id) && website.gtm_container_id.present?
          config[:gtm_id] = website.gtm_container_id
        end

        if website.respond_to?(:posthog_api_key) && website.posthog_api_key.present?
          config[:posthog_key] = website.posthog_api_key
          config[:posthog_host] = website.posthog_host || 'https://app.posthog.com'
        end

        config.presence
      end

      def build_navigation(website)
        {
          top_nav: build_nav_items(website, :top),
          footer_nav: build_nav_items(website, :footer)
        }
      end

      def build_nav_items(website, position)
        scope = website.pages.where(visible: true)
        scope = position == :top ? scope.where(show_in_top_nav: true) : scope.where(show_in_footer: true)
        order_column = position == :top ? :sort_order_top_nav : :sort_order_footer

        scope.order(order_column, :slug).map do |page|
          {
            id: page.id,
            slug: page.slug,
            title: page.page_title || page.slug.titleize,
            path: "/#{page.slug}"
          }
        end
      end

      def build_pages_summary(website)
        website.pages.order(:sort_order_top_nav, :slug).map do |page|
          {
            id: page.id,
            slug: page.slug,
            title: page.page_title || page.slug.titleize,
            visible: page.visible,
            show_in_top_nav: page.show_in_top_nav,
            show_in_footer: page.show_in_footer,
            updated_at: page.updated_at.iso8601
          }
        end
      end

      def build_theme_info(website)
        theme_name = website.theme_name || 'default'

        {
          name: theme_name,
          display_name: theme_name.titleize
        }
      end

      def build_field_schema
        {
          fields: [
            Pwb::FieldSchemaBuilder.build_field_definition(:company_display_name, {
              type: :text,
              label: 'Company Name',
              hint: 'Your company or website name displayed in headers and SEO',
              required: true,
              max_length: 100,
              group: :branding
            }),
            Pwb::FieldSchemaBuilder.build_field_definition(:default_meta_description, {
              type: :textarea,
              label: 'Default Meta Description',
              hint: 'Default description for SEO (used when pages don\'t have their own)',
              max_length: 160,
              rows: 3,
              content_guidance: {
                recommended_length: '120-160 characters',
                seo_tip: 'This appears in search results - make it compelling'
              },
              group: :seo
            }),
            Pwb::FieldSchemaBuilder.build_field_definition(:default_client_locale, {
              type: :select,
              label: 'Default Language',
              hint: 'The primary language for your website',
              choices: [
                { value: 'en', label: 'English' },
                { value: 'es', label: 'Spanish' },
                { value: 'de', label: 'German' },
                { value: 'fr', label: 'French' },
                { value: 'it', label: 'Italian' },
                { value: 'pt', label: 'Portuguese' },
                { value: 'nl', label: 'Dutch' }
              ],
              default: 'en',
              group: :localization
            }),
            Pwb::FieldSchemaBuilder.build_field_definition(:ga4_measurement_id, {
              type: :text,
              label: 'Google Analytics 4 ID',
              hint: 'Your GA4 Measurement ID (e.g., G-XXXXXXXXXX)',
              placeholder: 'G-XXXXXXXXXX',
              max_length: 20,
              group: :analytics
            }),
            Pwb::FieldSchemaBuilder.build_field_definition(:gtm_container_id, {
              type: :text,
              label: 'Google Tag Manager ID',
              hint: 'Your GTM Container ID (e.g., GTM-XXXXXXX)',
              placeholder: 'GTM-XXXXXXX',
              max_length: 20,
              group: :analytics
            }),
            Pwb::FieldSchemaBuilder.build_field_definition(:posthog_api_key, {
              type: :text,
              label: 'PostHog API Key',
              hint: 'Your PostHog project API key for analytics',
              max_length: 100,
              group: :analytics
            }),
            Pwb::FieldSchemaBuilder.build_field_definition(:posthog_host, {
              type: :url,
              label: 'PostHog Host',
              hint: 'PostHog instance URL (leave empty for cloud)',
              placeholder: 'https://app.posthog.com',
              group: :analytics
            })
          ],
          groups: [
            { key: 'branding', label: 'Branding', order: 1 },
            { key: 'seo', label: 'SEO Settings', order: 2 },
            { key: 'localization', label: 'Language', order: 3 },
            { key: 'analytics', label: 'Analytics', order: 4 }
          ]
        }
      end
    end
  end
end
