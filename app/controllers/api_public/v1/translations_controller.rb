module ApiPublic
  module V1
    class TranslationsController < BaseController
      include ApiPublic::Cacheable

      def index
        locale = params[:locale]
        return render json: { error: "Locale is required" }, status: :bad_request unless locale

        # Translations are static per locale - cache for a long time
        # ETag based on locale and app version/deploy timestamp
        etag_data = [locale, Rails.application.config.respond_to?(:version) ? Rails.application.config.version : "1.0"]
        set_long_cache(max_age: 24.hours, etag_data: etag_data)
        return if performed?

        render json: {
          locale: locale,
          result: I18n.t(".", locale: locale)
        }
      end
    end
  end
end
