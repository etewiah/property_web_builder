module Pwb
  module Devise
    class SessionsController < ::Devise::SessionsController
      # Include the application controller concern for subdomain tenant detection
      before_action :validate_user_website, only: [:create]

      protected

      # Validate that the user belongs to the current website/subdomain
      def validate_user_website
        # Get the email from sign_in params
        email = sign_in_params[:email]
        return unless email.present?

        # Find user by email
        user = Pwb::User.find_by(email: email)
        return unless user.present?

        # Get current website from subdomain
        current_site = current_website_from_subdomain
        
        # Check if user's website matches current subdomain
        if user.website_id != current_site&.id
          flash[:alert] = "You don't have access to this subdomain. Please use the correct subdomain for your account."
          redirect_to new_user_session_path and return
        end
      end

      # Helper to get current website from subdomain
      # This duplicates logic from ApplicationController but needs to be available here
      def current_website_from_subdomain
        subdomain = request.subdomain
        return nil if subdomain.blank?
        
        reserved_subdomains = %w[www api admin]
        return nil if reserved_subdomains.include?(subdomain.downcase)
        
        Pwb::Website.find_by_subdomain(subdomain)
      end

      def sign_in_params
        params.require(:user).permit(:email, :password, :remember_me)
      end
    end
  end
end
