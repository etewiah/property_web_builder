# frozen_string_literal: true

module SiteAdmin
  module Website
    class SettingsController < ::SiteAdminController
      before_action :set_website
      before_action :set_tab

      VALID_TABS = %w[general appearance navigation home].freeze

      def show
        case @tab
        when 'navigation'
          @top_nav_links = @website.links.ordered_top_nav
          @footer_links = @website.links.ordered_footer
        when 'home'
          @home_page = @website.pages.find_by(slug: 'home')
          @carousel_contents = @website.contents.where(tag: 'carousel')
        when 'appearance'
          @themes = Pwb::Theme.all
          @style_variables = @website.style_variables
        end
      end

      def update
        case @tab
        when 'general'
          update_general_settings
        when 'appearance'
          update_appearance_settings
        when 'home'
          update_home_settings
        else
          redirect_to site_admin_website_settings_path, alert: 'Invalid tab'
          return
        end
      end

      def update_links
        if params[:links].present?
          update_navigation_links
          redirect_to site_admin_website_settings_tab_path('navigation'), notice: 'Navigation links updated successfully'
        else
          redirect_to site_admin_website_settings_tab_path('navigation'), alert: 'No links data provided'
        end
      end

      private

      def set_website
        @website = current_website
      end

      def set_tab
        @tab = params[:tab].presence || 'general'
        unless VALID_TABS.include?(@tab)
          redirect_to site_admin_website_settings_path, alert: 'Invalid tab'
        end
      end

      def update_general_settings
        if @website.update(general_settings_params)
          redirect_to site_admin_website_settings_tab_path('general'), notice: 'General settings updated successfully'
        else
          flash.now[:alert] = 'Failed to update general settings'
          render :show, status: :unprocessable_entity
        end
      end

      def update_appearance_settings
        # Handle style_variables separately since it's a nested structure
        if params[:website][:style_variables].present?
          @website.style_variables = params[:website][:style_variables].to_unsafe_h
        end

        if @website.update(appearance_settings_params)
          redirect_to site_admin_website_settings_tab_path('appearance'), notice: 'Appearance settings updated successfully'
        else
          @themes = Pwb::Theme.all
          @style_variables = @website.style_variables
          flash.now[:alert] = 'Failed to update appearance settings'
          render :show, status: :unprocessable_entity
        end
      end

      def update_home_settings
        # Handle page title updates
        if params[:page].present?
          @home_page = @website.pages.find_by(slug: 'home')
          if @home_page&.update(home_page_params)
            redirect_to site_admin_website_settings_tab_path('home'), notice: 'Home page title updated successfully'
            return
          else
            @carousel_contents = @website.contents.where(tag: 'carousel')
            flash.now[:alert] = 'Failed to update home page title'
            render :show, status: :unprocessable_entity
            return
          end
        end

        # Handle website display options (landing_hide_* flags)
        if params[:website].present?
          if @website.update(home_display_params)
            redirect_to site_admin_website_settings_tab_path('home'), notice: 'Display options updated successfully'
          else
            @home_page = @website.pages.find_by(slug: 'home')
            @carousel_contents = @website.contents.where(tag: 'carousel')
            flash.now[:alert] = 'Failed to update display options'
            render :show, status: :unprocessable_entity
          end
        else
          redirect_to site_admin_website_settings_tab_path('home')
        end
      end

      def update_navigation_links
        params[:links].each do |link_params|
          link = @website.links.find_by(id: link_params[:id])
          next unless link

          link.update(
            link_title: link_params[:link_title],
            link_path: link_params[:link_path],
            visible: link_params[:visible] == 'true' || link_params[:visible] == true,
            sort_order: link_params[:sort_order]
          )
        end
      end

      def general_settings_params
        params.require(:website).permit(
          :company_display_name,
          :default_client_locale,
          :default_currency,
          :default_area_unit,
          :analytics_id,
          :analytics_id_type,
          supported_locales: []
        )
      end

      def appearance_settings_params
        params.require(:website).permit(
          :theme_name,
          :raw_css
        )
      end

      def home_page_params
        params.require(:page).permit(:page_title)
      end

      def home_display_params
        params.require(:website).permit(
          :landing_hide_for_rent,
          :landing_hide_for_sale,
          :landing_hide_search_bar
        )
      end
    end
  end
end
