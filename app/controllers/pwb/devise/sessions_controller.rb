module Pwb
  module Devise
    class SessionsController < ::Devise::SessionsController
      # Include subdomain tenant detection to set Pwb::Current.website
      include SubdomainTenant
      # Redirect to Firebase if that's the configured auth provider
      include AuthProviderRedirect
      helper AuthHelper

      layout 'devise_tailwind'

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

        # Use the website already resolved by SubdomainTenant concern
        # This ensures consistency with how the rest of the app resolves the current tenant
        current_site = Pwb::Current.website

        # Check if user's website matches current subdomain
        if user.website_id != current_site&.id
          flash[:alert] = "You don't have access to this subdomain. Please use the correct subdomain for your account."
          redirect_to new_user_session_path and return
        end
      end

      def sign_in_params
        params.fetch(:user, ActionController::Parameters.new).permit(:email, :password, :remember_me)
      end
    end
  end
end
