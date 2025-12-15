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

      # Get the website specifically for this subdomain (not fallback)
      website_for_subdomain = current_website_from_subdomain

      # Check if this subdomain has a website that allows signups
      unless website_for_subdomain
        @token_error = "This website is not yet available. If you're setting up a new site, please complete the signup process first."
        render "pwb/firebase_login/sign_up_error", layout: "devise_tailwind" and return
      end

      # Only allow signups for websites in appropriate states
      unless website_for_subdomain.live? || website_for_subdomain.locked_pending_registration?
        @token_error = "This website is not ready for account creation. Please complete the setup process first."
        render "pwb/firebase_login/sign_up_error", layout: "devise_tailwind" and return
      end

      # If website is pending registration (owner email verified but not yet signed up),
      # restrict signup to only the owner email AND require verification token
      if website_for_subdomain.locked_pending_registration?
        @require_owner_email = true
        @required_email = website_for_subdomain.owner_email
        @verification_token = params[:token]

        # Validate the token - must match the website's verification token
        unless @verification_token.present? && @verification_token == website_for_subdomain.email_verification_token
          @token_error = "Invalid or missing verification token. Please use the link from your verification email."
          render "pwb/firebase_login/sign_up_error", layout: "devise_tailwind" and return
        end
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
