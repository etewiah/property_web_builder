module ApiPublic
  module V1
    class SiteDetailsController < BaseController

      def index
        locale = params[:locale]
        if locale
          I18n.locale = locale
        end
        
        render json: Pwb::Current.website.as_json
      end
    end
  end
end
