module ApiPublic
  module V1
    class PagesController < BaseController

      def show
        page = Pwb::Current.website.pages.find(params[:id])
        render json: page.as_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Page not found" }, status: :not_found
      end

      def show_by_slug
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale
        page = Pwb::Current.website.pages.find_by_slug(params[:slug])
        
        if page
          render json: page.as_json
        else
          render json: { error: "Page not found" }, status: :not_found
        end
      end
    end
  end
end
