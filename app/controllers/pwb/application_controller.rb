module Pwb
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    helper AuthHelper

    before_action :current_agency_and_website, :check_unseeded_website, :check_locked_website, :nav_links,
      :set_locale, :set_theme_path, :footer_content

    # Themes allowed to be switched via ?theme= URL parameter
    ALLOWED_THEMES = %w[default brisbane bologna].freeze

    include DemoRestrictions
    include ActiveStorage::SetCurrent

    around_action :connect_to_tenant_shard

    # Connect PwbTenant:: models to the appropriate shard based on current website.
    #
    # IMPORTANT: Only PwbTenant::ApplicationRecord is switched to the shard.
    # Pwb:: models (ContentPhoto, Website, etc.) always use the primary database.
    # This prevents "No connection pool" errors when Pwb:: models are queried
    # inside the shard connection block.
    def connect_to_tenant_shard
      website = current_website
      shard = website&.database_shard || :default

      # Only switch PwbTenant models to the shard
      # Pwb:: models continue using primary database automatically
      PwbTenant::ApplicationRecord.connected_to(shard: shard, role: :writing) do
        yield
      end
    end

    def set_theme_path
      theme_name = current_website&.theme_name
      if params[:theme].present?
        if ALLOWED_THEMES.include?(params[:theme])
          theme_name = params[:theme]
        end
      end
      theme_name = theme_name.present? ? theme_name : "default"

      # Use Theme model's view_paths for proper inheritance support
      # This allows child themes to automatically inherit views from parent themes
      theme = Theme.find_by(name: theme_name) || Theme.find_by(name: "default")
      if theme
        # Prepend in reverse order so theme-specific paths have highest priority
        theme.view_paths.reverse_each { |path| prepend_view_path path }
      else
        # Fallback to hardcoded path if theme not found
        prepend_view_path "#{Rails.root}/app/themes/#{theme_name}/views/"
      end

      self.class.layout "layouts/pwb/application"
    end

    def set_locale
      # agency = current_agency
      locale = current_website&.default_client_locale_to_use || "en"
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
      @current_website = current_website_from_subdomain || Pwb::Current.website || Website.first
      # Ensure Pwb::Current.website is set for Ahoy analytics and other services
      Pwb::Current.website ||= @current_website
      # Set ActsAsTenant for PwbTenant:: models
      ActsAsTenant.current_tenant = @current_website
      @current_agency = @current_website&.agency || @current_website&.build_agency
    end

    # Check if no website exists for this subdomain and redirect to setup
    # This happens when a new subdomain is accessed that hasn't been seeded
    def check_unseeded_website
      return if @current_website.present?

      # Skip for setup routes
      return if request.path.start_with?('/setup')

      # Redirect to setup page
      redirect_to pwb_setup_path
    end

    # Check if the website is in a locked state and render appropriate view
    # Only show locked page on the landing page (root path)
    # Other pages are accessible if user knows the specific URL
    def check_locked_website
      return unless @current_website&.locked?
      return unless request.path == '/' || request.path == root_path

      @locked_mode = @current_website.locked_mode
      @owner_email = @current_website.owner_email

      # Render locked page and halt the filter chain
      render 'pwb/locked/show', layout: 'pwb/locked', status: :ok
    end

    # Reserved subdomains that should not be used for tenant resolution
    RESERVED_SUBDOMAINS = %w[www api admin].freeze

    # Determine the current website based on subdomain
    def current_website_from_subdomain
      subdomain = request.subdomain
      return nil if subdomain.blank?
      return nil if RESERVED_SUBDOMAINS.include?(subdomain.downcase)
      Website.find_by_subdomain(subdomain)
    end

    # Returns the current website, preferring @current_website if already set
    def current_website
      @current_website ||= current_website_from_subdomain || Pwb::Current.website || Website.first
    end

    def footer_content
      # Cache footer content per website with short TTL for freshness
      cache_key = "footer_content/#{current_website&.id}/#{current_website&.updated_at&.to_i}"
      @footer_content = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        footer_page_content = current_website&.ordered_visible_page_contents&.find_by_page_part_key "footer_content_html"
        footer_page_content.present? ? footer_page_content.content : OpenStruct.new
      end
    end

    def nav_links
      # Cache admin link visibility per website
      cache_key = "nav_admin_link/#{current_website&.id}/#{current_website&.updated_at&.to_i}"
      if current_user
        # where user is signed in, special admin link is shown
        # so no need to render standard one
        @show_admin_link = false
      else
        @show_admin_link = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
          top_nav_admin_link = @current_website&.links&.find_by_slug("top_nav_admin")
          top_nav_admin_link&.visible || false
        end
      end
    end
  end
end
