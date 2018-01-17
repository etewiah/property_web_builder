module Pwb
  class OmniauthController < ApplicationController
  # https://github.com/plataformatec/devise/wiki/How-To:-OmniAuth-inside-localized-scope
    def localized
      # Just save the current locale in the session and redirect to the unscoped path as before
      session[:omniauth_login_locale] = I18n.locale
      # user_facebook_omniauth_authorize_path
      # redirect_to user_omniauth_authorize_path(params[:provider])
      redirect_to omniauth_authorize_path("user",params[:provider])
    end
  end
end
