module ApiPublic
  module V1
    class SiteDetailsController < BaseController
      include ApiPublic::Cacheable

      def index
        locale = params[:locale]
        I18n.locale = locale if locale.present?

        website = Pwb::Current.website

        # Cache site details for 1 hour - changes infrequently
        etag_data = [website.id, website.updated_at]
        set_long_cache(max_age: 1.hour, etag_data: etag_data)
        return if performed?

        render json: website.as_json.merge(
          analytics: build_analytics_config(website)
        )
      end

      private

      def build_analytics_config(website)
        config = {}

        # Posthog
        if website.respond_to?(:posthog_api_key) && website.posthog_api_key.present?
          config[:posthog_key] = website.posthog_api_key
          config[:posthog_host] = website.respond_to?(:posthog_host) ? website.posthog_host : "https://app.posthog.com"
        end

        # Google Analytics 4
        config[:ga4_id] = website.ga4_measurement_id if website.respond_to?(:ga4_measurement_id) && website.ga4_measurement_id.present?

        # Google Tag Manager
        config[:gtm_id] = website.gtm_container_id if website.respond_to?(:gtm_container_id) && website.gtm_container_id.present?

        config.presence
      end
    end
  end
end
