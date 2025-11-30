module Pwb
  class FirebaseLoginController < ApplicationController
    layout 'pwb/devise'

    def index
      render "pwb/firebase_login/index"
    end
  end
end
