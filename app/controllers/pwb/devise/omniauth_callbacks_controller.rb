# I get a circular dependency error is I nest below in a Pwb module
class Pwb::Devise::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def facebook
    # https://github.com/plataformatec/devise/wiki/How-To:-OmniAuth-inside-localized-scope
    # Use the session locale set earlier; use the default if it isn't available.
    I18n.locale = session[:omniauth_login_locale] || I18n.default_locale

    @user = Pwb::User.find_for_oauth(request.env['omniauth.auth'])
    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: 'Facebook') if is_navigational_format?
    end
  end
end
