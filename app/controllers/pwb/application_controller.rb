module Pwb
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    before_action :current_agency_and_website, :nav_links,
      :set_locale, :set_theme_path, :footer_content

    def set_theme_path
      theme_name = Website.unique_instance.theme_name
      if params[:theme].present?
        if %w(berlin default).include? params[:theme]
          theme_name = params[:theme]
        end
      end
      theme_name = theme_name.present? ? theme_name : "default"
      # prepend_view_path "#{Pwb::Engine.root}/app/themes/#{theme_name}/views/"
      # below allows themes installed in Rails app consuming Pwb to work
      prepend_view_path "#{Rails.root}/app/themes/#{theme_name}/views/"

      self.class.layout "#{Rails.root}/app/themes/#{theme_name}/views/layouts/pwb/application"
    end

    def set_locale
      # agency = current_agency
      locale = Website.unique_instance.default_client_locale_to_use
      # below just causes confusion for now
      # if current_user
      #   locale = current_user.default_client_locale
      # end
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
      @current_website = Website.unique_instance
    end

    def footer_content
      # @footer_content = Content.find_by_key("footerInfo") || OpenStruct.new
      footer_page_content = Website.unique_instance.ordered_visible_page_contents.find_by_page_part_key "footer_content_html"
      @footer_content = footer_page_content.present? ? footer_page_content.content : OpenStruct.new
      # TODO: Cache above
    end

    def nav_links
      # @sections ||= Section.order("sort_order")
      if current_user
        # where user is signed in, special admin link is shown
        # so no need to render standard one
        @show_admin_link = false
      else
        @show_admin_link = false
        top_nav_admin_link = Pwb::Link.find_by_slug("top_nav_admin")
        if top_nav_admin_link && top_nav_admin_link.visible
          @show_admin_link = true
        end
      end
    end
  end
end
