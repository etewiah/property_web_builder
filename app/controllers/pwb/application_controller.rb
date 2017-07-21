module Pwb
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    before_action :footer_content, :current_agency_and_website, :sections,
      :set_locale, :set_theme_path

    def set_theme_path
      theme_name = Website.unique_instance.theme_name
      theme_name = theme_name.present? ? theme_name : "default"
      # || "default"
      # if Agency.last && Agency.last.theme_name.present?
      #   theme_name = Agency.last.theme_name
      # end
      prepend_view_path "#{Pwb::Engine.root}/app/themes/#{theme_name}/views/"
      # below allows themes installed in Rails app consuming Pwb to work
      prepend_view_path "#{Rails.root}/app/themes/#{theme_name}/views/"

      self.class.layout "#{Pwb::Engine.root}/app/themes/#{theme_name}/views/layouts/pwb/application"
    end

    def set_locale
      # agency = current_agency
      locale = Website.unique_instance.default_client_locale_to_use
      # below just causes confusion for now
      # if current_user
      #   locale = current_user.default_client_locale
      # end
      # byebug
      if params[:locale] && (I18n.locale_available? params[:locale])
        # passed in params override user's default
        locale = params[:locale]
      end
      I18n.locale = locale.to_sym

      # Globalize.fallbacks = {:de => [:en],:es => [:en], :ru => [:en]}
    end

    # http://www.rubydoc.info/github/plataformatec/devise/master/ActionDispatch/Routing/Mapper#devise_for-instance_method
    # below needed so devise can route links with correct locale
    def self.default_url_options
      { locale: I18n.locale }
    end

    private

    def current_agency_and_website
      @current_agency ||= Agency.unique_instance
      # (Agency.last || Agency.create)
      @current_website = Website.unique_instance
    end

    def footer_content
      @footer_content = Content.find_by_key("footerInfo") || OpenStruct.new
    end

    def sections
      @sections ||= Section.order("sort_order")
      if current_user
        # where user is signed in, special admin link is shown
        # so no need to render standard one
        @show_admin_link = false
      else
        @show_admin_link = Pwb::Link.find_by_slug("top_nav_admin").visible
      end
    end
  end
end
