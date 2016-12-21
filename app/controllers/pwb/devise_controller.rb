module Pwb
  class DeviseController < ActionController::Base
    protect_from_forgery with: :exception

    before_filter :current_agency, :sections, :set_locale

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
