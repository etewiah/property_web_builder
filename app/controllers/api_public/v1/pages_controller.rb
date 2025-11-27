module ApiPublic
  module V1
    class PagesController < BaseController

      def show
        unless website_provisioned?
          render json: website_not_provisioned_error, status: :not_found
          return
        end

        page = Pwb::Current.website.pages.find(params[:id])
        render json: page.as_json
      rescue ActiveRecord::RecordNotFound
        render json: { 
          error: "Page not found",
          message: "No page exists with id '#{params[:id]}' for this website",
          code: "PAGE_NOT_FOUND"
        }, status: :not_found
      end

      def show_by_slug
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale

        unless website_provisioned?
          render json: website_not_provisioned_error, status: :not_found
          return
        end

        page = Pwb::Current.website.pages.find_by_slug(params[:slug])
        
        if page
          render json: page.as_json
        else
          render json: { 
            error: "Page not found",
            message: "No page exists with slug '#{params[:slug]}' for this website. Available pages: #{available_page_slugs.join(', ')}",
            code: "PAGE_NOT_FOUND"
          }, status: :not_found
        end
      end

      private

      def website_provisioned?
        Pwb::Current.website.present? && Pwb::Current.website.pages.exists?
      end

      def website_not_provisioned_error
        {
          error: "Website not provisioned",
          message: "The website has not been provisioned with any pages. Please run the setup/seeding process to create initial pages.",
          code: "WEBSITE_NOT_PROVISIONED"
        }
      end

      def available_page_slugs
        Pwb::Current.website.pages.pluck(:slug).compact
      end
    end
  end
end
