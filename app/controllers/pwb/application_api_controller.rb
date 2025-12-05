module Pwb
  class ApplicationApiController < ActionController::Base
    protect_from_forgery with: :exception, prepend: true
    # include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :authenticate_user!, :current_agency, :check_user, unless: :bypass_authentication?
    # , :authenticate_user_from_token!, :set_locale
    after_action :set_csrf_token

    def self.default_url_options
      { locale: I18n.locale }
    end

    private

    ALLOWED_BYPASS_ENVIRONMENTS = %w[development e2e test].freeze

    def bypass_authentication?
      return false unless ALLOWED_BYPASS_ENVIRONMENTS.include?(Rails.env)
      ENV['BYPASS_API_AUTH'] == 'true' || ENV['BYPASS_ADMIN_AUTH'] == 'true'
    end

    def check_user
      puts "ApplicationApiController#check_user reached"
      return if bypass_authentication?

      # Allow if user is admin for the current website
      unless current_user && current_user.admin_for?(current_website)
        # unless request.subdomain.present? && (request.subdomain.downcase == current_user.tenants.first.subdomain.downcase)
        render_json_error "unauthorised_user"
      end
    end

    def render_json_error(message, opts = {})
      render json: message, status: opts[:status] || 422
    end

    def current_agency
      puts "ApplicationApiController#current_agency reached"
      @current_agency ||= current_website.agency || current_website.build_agency
    end

    def current_website
      @current_website ||= current_website_from_subdomain || Pwb::Current.website || Website.first
    end

    def current_website_from_subdomain
      return nil unless request.subdomain.present?
      Website.find_by_subdomain(request.subdomain)
    end

    def set_csrf_token
      # http://rajatsingla.in/ruby/2016/08/06/how-to-add-csrf-in-ember-app.html
      if request.xhr?
        response.headers["X-CSRF-Token"] = form_authenticity_token.to_s
        response.headers["X-CSRF-Param"] = "authenticity_token"
      end
      # works in conjunction with updating the headers via client app
    end
  end
end
