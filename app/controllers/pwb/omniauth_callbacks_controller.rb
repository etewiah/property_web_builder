require_dependency 'pwb/application_controller'

module Pwb
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def facebook
      # https://github.com/plataformatec/devise/wiki/How-To:-OmniAuth-inside-localized-scope
      # Use the session locale set earlier; use the default if it isn't available.
      I18n.locale = session[:omniauth_login_locale] || I18n.default_locale

      @user = User.find_for_oauth(request.env['omniauth.auth'])
      if @user.persisted?
        sign_in_and_redirect @user, event: :authentication
        set_flash_message(:notice, :success, kind: 'Facebook') if is_navigational_format?
      end
    end
  end
end
