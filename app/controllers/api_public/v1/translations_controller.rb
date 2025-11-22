module ApiPublic
  module V1
    class TranslationsController < BaseController

      def index
        locale = params[:locale]
        unless locale
          return render json: { error: "Locale is required" }, status: :bad_request
        end

        render json: {
          locale: locale,
          result: I18n.t(".", locale: locale)
        }
      end
    end
  end
end
