# frozen_string_literal: true

module Pwb
  # Unified authentication controller for handling auth operations
  # that work across both Firebase and Devise authentication providers.
  #
  # This controller provides a consistent logout experience regardless
  # of the configured authentication provider.
  class AuthController < ApplicationController
    # Unified logout action
    # Signs out from Devise session and, if using Firebase,
    # also signs out from Firebase client-side.
    def logout
      # Log the logout event before signing out
      if current_user
        Pwb::AuthAuditLog.log_logout(user: current_user, request: request)
      end

      # Sign out from Devise session
      sign_out(current_user)

      # If using Firebase, redirect to Firebase logout page
      # which will sign out from Firebase client-side
      if Pwb::AuthConfig.firebase?
        render 'pwb/auth/firebase_logout'
      else
        redirect_to root_path, notice: 'Signed out successfully.'
      end
    end
  end
end
