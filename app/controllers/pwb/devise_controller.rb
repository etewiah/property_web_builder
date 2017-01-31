module Pwb
  class DeviseController < ApplicationController
    # # ActionController::Base
    #  protect_from_forgery with: :exception

    #  # before_action :current_agency, :sections, :set_locale, :set_theme_path
    #  # before_action :configure_permitted_parameters, if: :devise_controller?


    #  def set_theme_path
    #    @is_devise = true
    #    theme_name = "default"
    #    if Agency.last && Agency.last.theme_name.present?
    #      theme_name = Agency.last.theme_name
    #    end
    #    prepend_view_path "#{Pwb::Engine.root}/app/themes/#{theme_name}/views/"
    #    # below allows themes installed in Rails app consuming Pwb to work
    #    prepend_view_path "#{Rails.root}/app/themes/#{theme_name}/views/"

    #    self.class.layout "#{Pwb::Engine.root}/app/themes/#{theme_name}/views/layouts/pwb/application"
    #  end


    #  def set_locale
    #    agency = current_agency
    #    locale = agency.default_client_locale_to_use
    #    if params[:locale]
    #      # passed in params override user's default
    #      locale = params[:locale]
    #    end
    #    I18n.locale = locale
    #  end

    #  # http://www.rubydoc.info/github/plataformatec/devise/master/ActionDispatch/Routing/Mapper#devise_for-instance_method
    #  # below needed so devise can route links with correct locale
    #  def self.default_url_options
    #    { locale: I18n.locale }
    #  end

    #  private

    #  def current_agency
    #    @current_agency ||= (Agency.last || Agency.create)
    #  end

    #  def sections
    #    @sections ||= Section.where(visible: true).order("sort_order")
    #    @show_admin_link = true
    #  end

    # def configure_permitted_parameters
    #   # http://stackoverflow.com/questions/34510155/cant-add-custom-fields-to-devise-model-in-ruby-on-rails-private-method-error
    #   devise_parameter_sanitizer.permit(:sign_up) do |user_params|
    #     user_params.permit({ roles: [] }, :email, :password, :password_confirmation)
    #   end
    # end

    # https://github.com/plataformatec/devise/blob/master/lib/devise/controllers/helpers.rb

    # Method used by sessions controller to sign out a user. You can overwrite
    # it in your ApplicationController to provide a custom hook for a custom
    # scope. Notice that differently from +after_sign_in_path_for+ this method
    # receives a symbol with the scope, and not the resource.
    #
    # Overwriting the sign_out redirect path method
    # By default it is the root_path.
    def after_sign_out_path_for(resource_or_scope)
      # scope = Devise::Mapping.find_scope!(resource_or_scope)
      # router_name = Devise.mappings[scope].router_name
      # context = router_name ? send(router_name) : self
      # context.respond_to?(:root_path) ? context.root_path : "/"
      pwb.home_path
    end


    def after_sign_in_path_for(resource_or_scope)
      # TODO - check for admin v standard users
      pwb.admin_path
      # stored_location_for(resource_or_scope) || signed_in_root_path(resource_or_scope)
    end
  end
end
