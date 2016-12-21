module Pwb
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    before_filter :current_agency, :sections, :set_locale, :set_theme_path

    def set_theme_path
      prepend_view_path "#{Pwb::Engine.root}/app/themes/chic/views/"
      # below allows themes installed in Rails app consuming Pwb to work
      prepend_view_path "#{Rails.root}/app/themes/default/views/"
    end

    def set_locale
      agency = current_agency
      locale = agency.default_client_locale_to_use
      # below just causes confusion for now
      # if current_user
      #   locale = current_user.default_client_locale
      # end
      if params[:locale]
        # passed in params override user's default
        locale = params[:locale]
      end
      I18n.locale = locale
    end

    # http://www.rubydoc.info/github/plataformatec/devise/master/ActionDispatch/Routing/Mapper#devise_for-instance_method
    # below needed so devise can route links with correct locale
    def self.default_url_options
      { locale: I18n.locale }
    end

    private

    def current_agency
      @current_agency ||= (Agency.last || Agency.create)
    end

    def sections
      @sections ||= Section.where(visible: true).order("sort_order")
      @show_admin_link = true
    end

  end
end
