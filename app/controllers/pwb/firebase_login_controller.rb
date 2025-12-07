module Pwb
  class FirebaseLoginController < ActionController::Base
    include ::Devise::Controllers::Helpers
    helper_method :current_user

    layout 'devise_tailwind'

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
      render "pwb/firebase_login/sign_up"
    end

    def change_password
      # Require user to be authenticated
      unless current_user
        redirect_to "/firebase_login" and return
      end
      render "pwb/firebase_login/change_password"
    end

    private

    def redirect_if_signed_in
      redirect_to admin_path if user_signed_in?
    end

    def admin_path
      '/admin'
    end
  end
end
