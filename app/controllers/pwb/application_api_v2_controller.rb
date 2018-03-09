module Pwb
  class ApplicationApiV2Controller < ActionController::Base
    protect_from_forgery with: :exception, prepend: true
    # include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :authenticate_user!, :current_agency, :check_user
    # , :authenticate_user_from_token!, :set_locale
    after_action :set_csrf_token


    before_action :cors_preflight_check
    after_action :cors_set_access_control_headers
    # For all responses in this controller, return the CORS access control headers.

    def cors_set_access_control_headers
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
      headers['Access-Control-Max-Age'] = "1728000"
    end

    # If this is a preflight OPTIONS request, then short-circuit the
    # request, return only the necessary headers and return an empty
    # text/plain.

    def cors_preflight_check
      if request.method == :options
        headers['Access-Control-Allow-Origin'] = '*'
        headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
        headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-Prototype-Version'
        headers['Access-Control-Max-Age'] = '1728000'
        render text: '', content_type: 'text/plain'
      end
    end



    def self.default_url_options
      { locale: I18n.locale }
    end

    private

    def check_user
      unless current_user && current_user.admin
        # unless request.subdomain.present? && (request.subdomain.downcase == current_user.tenants.first.subdomain.downcase)
        render_json_error "unauthorised_user"
      end
    end

    def render_json_error(message, opts = {})
      render json: message, status: opts[:status] || 422
    end

    def current_agency
      @current_agency ||= (Agency.last || Agency.create)
    end

    def set_csrf_token
      # http://rajatsingla.in/2017/05/15/how-to-add-csrf-in-ember-app
      if request.xhr?
        response.headers['X-CSRF-Token'] = form_authenticity_token.to_s
        response.headers['X-CSRF-Param'] = "authenticity_token"
      end
      # works in conjunction with updating the headers via client app
    end
  end
end
