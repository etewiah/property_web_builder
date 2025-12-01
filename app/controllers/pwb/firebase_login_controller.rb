module Pwb
  class FirebaseLoginController < ApplicationController
    layout 'pwb/devise'

    def index
      render "pwb/firebase_login/index"
    end

    def forgot_password
      render "pwb/firebase_login/forgot_password"
    end

    def sign_up
      render "pwb/firebase_login/sign_up"
    end

    def change_password
      # Require user to be authenticated
      unless current_user
        redirect_to "/firebase_login" and return
      end
      render "pwb/firebase_login/change_password"
    end
  end
end
