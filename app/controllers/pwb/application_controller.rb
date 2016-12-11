module Pwb
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    before_filter :current_agency, :sections, :set_locale

    # def pundit_user
    #   binding.pry
    #   # UserContext.new(current_user, request.ip)
    # end

    def set_locale
      agency = current_agency
      if agency.default_client_locale.present?
        locale = agency.default_client_locale
      end

      if current_user
        locale = current_user.default_client_locale
      end
      if params[:locale]
        # passed in params override user's default
        locale = params[:locale]
      end
      # if params[:user] && params[:user][:default_locale]
      #   # This will catch registrations where a user might be halfway through
      #   # but needs to be returned error messages in the right locale
      #   locale = params[:user][:default_locale]
      # end
      I18n.locale = locale
    end


    # http://www.rubydoc.info/github/plataformatec/devise/master/ActionDispatch/Routing/Mapper#devise_for-instance_method
    # below needed so devise can route links with correct locale
    def self.default_url_options
      { locale: I18n.locale }
    end

    # considered below but decided against it
    # def favicon
    #   assets_path = File.join(Rails.root, "app/assets")
    #   binding.pry
    #   # http://softwareas.com/how-to-use-different-favicons-for-development-staging-and-production/
    #   path = assets_path + "/images/favicon/klavado/favicon-32x32.png"
    #   # below does not work for some reason:
    #   # ActionController::Base.helpers.asset_path "favicon/klavado/favicon-32x32.png"
    #    # "favicon#{env_suffix}.ico"
    #   send_file path, type:"image/x-icon", disposition:"inline"
    # end


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
