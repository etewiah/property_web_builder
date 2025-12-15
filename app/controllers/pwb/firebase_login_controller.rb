module Pwb
  class FirebaseLoginController < ActionController::Base
    include ::Devise::Controllers::Helpers
    helper_method :current_user, :current_website

    layout 'devise_tailwind'

    before_action :set_current_website
    before_action :redirect_if_signed_in, except: [:change_password]

    def index
      @return_url = params[:return_to] || stored_location_for(:user) || admin_path
      render "pwb/firebase_login/index"
    end

    def forgot_password
      render "pwb/firebase_login/forgot_password"
    end

    def sign_up
      @return_url = params[:return_to] || stored_location_for(:user) || admin_path

      # If website is pending registration (owner email verified but not yet signed up),
      # restrict signup to only the owner email
      if current_website&.locked_pending_registration?
        @require_owner_email = true
        @required_email = current_website.owner_email
      end

      render "pwb/firebase_login/sign_up"
    end

    def change_password
      # Require user to be authenticated
      unless current_user
        redirect_to "/pwb_login" and return
      end
      render "pwb/firebase_login/change_password"
    end

    private

    def set_current_website
      @current_website = current_website_from_subdomain
      Pwb::Current.website = @current_website
    end

    def current_website_from_subdomain
      subdomain = request.subdomain.presence
      return nil unless subdomain

      # Handle multi-level subdomains (e.g., "test.dev" -> "test")
      subdomain = subdomain.split('.').first if subdomain.include?('.')

      Pwb::Website.find_by(subdomain: subdomain)
    end

    def current_website
      @current_website ||= current_website_from_subdomain || Pwb::Current.website || Pwb::Website.first
    end

    def redirect_if_signed_in
      redirect_to admin_path if user_signed_in?
    end

    def admin_path
      '/admin'
    end
  end
end
