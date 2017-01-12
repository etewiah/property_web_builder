module Pwb
  class ApplicationApiController < ActionController::Base

    protect_from_forgery with: :exception, prepend: true
    # include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :authenticate_user!, :current_agency, :check_user
    # , :authenticate_user_from_token!, :set_locale
    after_action :set_csrf_token


    def self.default_url_options
      { locale: I18n.locale }
    end

    private

    def check_user
      unless current_user && current_user.admin
        # unless request.subdomain.present? && (request.subdomain.downcase == current_user.tenants.first.subdomain.downcase)
        return render_json_error "unauthorised_user"
      end

    end

    def render_json_error(message, opts={})
      render json: message, status: opts[:status] || 422
    end

    def current_agency
      @current_agency ||= (Agency.last || Agency.create)
    end

    def set_csrf_token
      # http://rajatsingla.in/ruby/2016/08/06/how-to-add-csrf-in-ember-app.html
      if request.xhr?
        response.headers['X-CSRF-Token'] = "#{form_authenticity_token}"
        response.headers['X-CSRF-Param'] = "authenticity_token"
      end
      # works in conjunction with updating the headers via client app
    end

  end
end
