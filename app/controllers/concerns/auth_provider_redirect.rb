# frozen_string_literal: true

# Concern to redirect users to the correct authentication provider
#
# When included in a Devise controller, it will redirect users to Firebase
# login pages if Firebase is the configured auth provider, preventing access
# to the Devise authentication forms.
#
# Usage:
#   class MyDeviseController < Devise::SessionsController
#     include AuthProviderRedirect
#   end
#
module AuthProviderRedirect
  extend ActiveSupport::Concern

  included do
    before_action :redirect_if_firebase_auth
  end

  private

  # Redirect to Firebase if that's the configured auth provider
  def redirect_if_firebase_auth
    return if Pwb::AuthConfig.devise?

    firebase_path = firebase_equivalent_path
    redirect_to firebase_path, notice: "Please use the Firebase login."
  end

  # Map Devise actions to Firebase equivalents
  def firebase_equivalent_path
    base_path = case controller_name
                when 'sessions'
                  '/pwb_login'
                when 'registrations'
                  action_name == 'edit' ? '/pwb_change_password' : '/pwb_sign_up'
                when 'passwords'
                  '/pwb_forgot_password'
                else
                  '/pwb_login'
                end

    # Preserve return_to parameter
    return_to = params[:return_to] || stored_location_for(:user)
    if return_to.present?
      "#{base_path}?return_to=#{CGI.escape(return_to)}"
    else
      base_path
    end
  end
end
