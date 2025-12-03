module Pwb
  class Api::V1::LitePropertiesController < JSONAPI::ResourceController
    before_action :set_current_website
    before_action :check_authentication

    # skip_before_action :verify_content_type_header
    # Skipping action below allows me to browse to endpoint
    # without having set mime type
    # skip_before_action :ensure_valid_accept_media_type
    # skip_before_action :verify_accept_header

    private

    def set_current_website
      Pwb::Current.website = current_website_from_subdomain
    end

    def current_website_from_subdomain
      return nil unless request.subdomain.present?
      Website.find_by_subdomain(request.subdomain)
    end

    def bypass_authentication?
      ENV['BYPASS_API_AUTH'] == 'true'
    end

    def check_authentication
      return true if bypass_authentication?

      authenticate_user!
      check_user_is_admin
    end

    def check_user_is_admin
      unless current_user && current_user.admin_for?(Pwb::Current.website)
        render json: "unauthorised_user", status: 422
      end
    end
  end
end
