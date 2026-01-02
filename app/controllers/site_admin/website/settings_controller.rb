# frozen_string_literal: true

module SiteAdmin
  module Website
    class SettingsController < ::SiteAdminController
      before_action :set_website
      before_action :set_tab

      VALID_TABS = %w[general appearance navigation home notifications seo social search].freeze

      def show
        # Always load website locales for multilingual editing
        @website_locales = build_website_locales

        case @tab
        when 'navigation'
          @top_nav_links = @website.links.ordered_top_nav
          @footer_links = @website.links.ordered_footer
        when 'home'
          @home_page = @website.pages.find_by(slug: 'home')
          @carousel_contents = @website.contents.where(tag: 'carousel')
        when 'appearance'
          # Only show themes that are accessible to this website
          @themes = @website.accessible_themes
          @style_variables = @website.style_variables
        when 'seo'
          @social_media = @website.social_media || {}
        when 'social'
          @social_links = @website.social_media_links_for_admin
        when 'search'
          @search_config = @website.search_configuration
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
        when 'notifications'
          update_notification_settings
        when 'seo'
          update_seo_settings
        when 'social'
          update_social_settings
        when 'search'
          update_search_settings
        else
          redirect_to site_admin_website_settings_path, alert: 'Invalid tab'
          return
        end
      end

      def test_notifications
        result = NtfyService.test_configuration(@website)
        if result[:success]
          redirect_to site_admin_website_settings_tab_path('notifications'), notice: result[:message]
        else
          redirect_to site_admin_website_settings_tab_path('notifications'), alert: result[:message]
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

      def reset_search_config
        if @website.update(search_config: {})
          redirect_to site_admin_website_settings_tab_path('search'), notice: 'Search configuration has been reset to defaults'
        else
          redirect_to site_admin_website_settings_tab_path('search'), alert: 'Failed to reset search configuration'
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
        # Filter out blank values from supported_locales (the hidden field submits "")
        filtered_params = general_settings_params.to_h
        if filtered_params[:supported_locales].is_a?(Array)
          filtered_params[:supported_locales] = filtered_params[:supported_locales].reject(&:blank?)
        end

        if @website.update(filtered_params)
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
          @themes = @website.accessible_themes
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

      def update_notification_settings
        # Don't clear the access token if the placeholder is submitted
        filtered_params = notification_settings_params.to_h
        if filtered_params[:ntfy_access_token] == '••••••••••••' || filtered_params[:ntfy_access_token].blank?
          filtered_params.delete(:ntfy_access_token)
        end

        if @website.update(filtered_params)
          redirect_to site_admin_website_settings_tab_path('notifications'), notice: 'Notification settings updated successfully'
        else
          flash.now[:alert] = 'Failed to update notification settings'
          render :show, status: :unprocessable_entity
        end
      end

      def update_seo_settings
        # Merge social_media settings
        if params[:social_media].present?
          current_social = @website.social_media || {}
          @website.social_media = current_social.merge(params[:social_media].to_unsafe_h)
        end

        if @website.update(seo_settings_params)
          redirect_to site_admin_website_settings_tab_path('seo'), notice: 'SEO settings updated successfully'
        else
          @social_media = @website.social_media || {}
          flash.now[:alert] = 'Failed to update SEO settings'
          render :show, status: :unprocessable_entity
        end
      end

      def update_social_settings
        if params[:social_links].present?
          params[:social_links].each do |platform, url|
            @website.update_social_media_link(platform, url)
          end
          redirect_to site_admin_website_settings_tab_path('social'), notice: 'Social media links updated successfully'
        else
          redirect_to site_admin_website_settings_tab_path('social'), alert: 'No social media data provided'
        end
      end

      def update_search_settings
        # Build the search config from form params
        new_config = build_search_config_from_params

        if @website.update_search_config(new_config)
          redirect_to site_admin_website_settings_tab_path('search'), notice: 'Search configuration updated successfully'
        else
          @search_config = @website.search_configuration
          flash.now[:alert] = 'Failed to update search configuration'
          render :show, status: :unprocessable_entity
        end
      end

      def update_navigation_links
        params[:links].each do |link_params|
          link = @website.links.find_by(id: link_params[:id])
          next unless link

          # Build update hash
          update_attrs = {
            link_path: link_params[:link_path],
            visible: link_params[:visible] == 'true' || link_params[:visible] == true,
            sort_order: link_params[:sort_order]
          }

          # Handle multilingual titles if provided
          if link_params[:titles].present?
            link_params[:titles].each do |locale, title|
              # Use Mobility's locale-specific setter
              Mobility.with_locale(locale.to_sym) do
                link.link_title = title
              end
            end
            link.save
          else
            # Fallback to single title for backwards compatibility
            update_attrs[:link_title] = link_params[:link_title] if link_params[:link_title].present?
            link.update(update_attrs)
          end
        end
      end

      def general_settings_params
        # Form submits as pwb_website (from model class name), but we also check :website for flexibility
        param_key = params.key?(:pwb_website) ? :pwb_website : :website
        params.require(param_key).permit(
          :company_display_name,
          :default_client_locale,
          :default_currency,
          :default_area_unit,
          :analytics_id,
          :analytics_id_type,
          :external_image_mode,
          supported_locales: [],
          available_currencies: []
        )
      end

      def appearance_settings_params
        params.require(:website).permit(
          :theme_name,
          :selected_palette,
          :dark_mode_setting,
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

      def notification_settings_params
        param_key = params.key?(:pwb_website) ? :pwb_website : :website
        params.require(param_key).permit(
          :ntfy_enabled,
          :ntfy_server_url,
          :ntfy_topic_prefix,
          :ntfy_access_token,
          :ntfy_notify_inquiries,
          :ntfy_notify_listings,
          :ntfy_notify_users,
          :ntfy_notify_security
        )
      end

      def seo_settings_params
        param_key = params.key?(:pwb_website) ? :pwb_website : :website
        params.require(param_key).permit(
          :default_seo_title,
          :default_meta_description,
          :favicon_url,
          :main_logo_url
        )
      end

      # Build search config hash from form parameters
      # Handles nested structure for filters, display, and listing_types
      def build_search_config_from_params
        return {} unless params[:search_config].present?

        config = {}
        search_params = params[:search_config]

        # Build filters config
        if search_params[:filters].present?
          config[:filters] = {}

          search_params[:filters].each do |filter_name, filter_config|
            config[:filters][filter_name] = build_filter_config(filter_name, filter_config)
          end
        end

        # Build display config
        if search_params[:display].present?
          config[:display] = {
            show_results_map: search_params[:display][:show_results_map] == '1',
            show_active_filters: search_params[:display][:show_active_filters] == '1',
            show_save_search: search_params[:display][:show_save_search] == '1',
            show_favorites: search_params[:display][:show_favorites] == '1',
            default_sort: search_params[:display][:default_sort],
            default_results_per_page: search_params[:display][:default_results_per_page].to_i
          }.compact
        end

        # Build listing_types config
        if search_params[:listing_types].present?
          config[:listing_types] = {}
          search_params[:listing_types].each do |type, type_config|
            config[:listing_types][type] = {
              enabled: type_config[:enabled] == '1',
              is_default: type_config[:is_default] == '1'
            }
          end
        end

        config
      end

      # Build config for a single filter from form params
      def build_filter_config(filter_name, filter_config)
        result = {
          enabled: filter_config[:enabled] == '1',
          position: filter_config[:position].to_i
        }

        # Input type
        result[:input_type] = filter_config[:input_type] if filter_config[:input_type].present?

        # Price filter has sale/rental specific config
        if filter_name.to_s == 'price'
          %w[sale rental].each do |listing_type|
            if filter_config[listing_type].present?
              type_config = filter_config[listing_type]
              result[listing_type.to_sym] = {
                min: parse_price_value(type_config[:min]),
                max: parse_price_value(type_config[:max]),
                default_min: parse_price_value(type_config[:default_min]),
                default_max: parse_price_value(type_config[:default_max]),
                step: type_config[:step].to_i.positive? ? type_config[:step].to_i : nil,
                min_presets: parse_price_presets(type_config[:min_presets]),
                max_presets: parse_price_presets(type_config[:max_presets]),
                presets: parse_presets(type_config[:presets]) # Legacy
              }.compact
            end
          end
        end

        # Bedroom/bathroom min/max options (new separate options)
        if filter_config[:min_options].present?
          result[:min_options] = parse_options(filter_config[:min_options])
        end
        if filter_config[:max_options].present?
          result[:max_options] = parse_options(filter_config[:max_options])
        end

        # Legacy: single options array (for backwards compatibility)
        if filter_config[:options].present?
          result[:options] = parse_options(filter_config[:options])
        end

        # Show max filter flag
        if filter_config.key?(:show_max_filter)
          result[:show_max_filter] = filter_config[:show_max_filter] == '1'
        end

        # Default values for non-price filters
        result[:default_min] = filter_config[:default_min].to_i if filter_config[:default_min].present?
        result[:default_max] = filter_config[:default_max].to_i if filter_config[:default_max].present?

        # Area-specific config
        result[:unit] = filter_config[:unit] if filter_config[:unit].present?
        if filter_config[:presets].present? && filter_name.to_s != 'price'
          result[:presets] = parse_presets(filter_config[:presets])
        end

        result.compact
      end

      # Parse price value, returning nil for blank/zero
      def parse_price_value(value)
        return nil if value.blank?

        parsed = value.to_s.gsub(/[,\s]/, '').to_i
        parsed.positive? ? parsed : nil
      end

      # Parse presets from comma-separated string or array
      def parse_presets(value)
        return nil if value.blank?

        if value.is_a?(String)
          value.split(',').map { |v| v.gsub(/[,\s]/, '').to_i }.reject(&:zero?)
        elsif value.is_a?(Array)
          value.map(&:to_i).reject(&:zero?)
        end
      end

      # Parse price presets that can include "No min" and "No max" strings
      def parse_price_presets(value)
        return nil if value.blank?

        if value.is_a?(String)
          value.split(',').map(&:strip).map do |v|
            # Keep "No min" and "No max" as strings
            if v.downcase == 'no min' || v.downcase == 'no max'
              v.downcase == 'no min' ? 'No min' : 'No max'
            else
              parsed = v.gsub(/[,\s]/, '').to_i
              parsed.positive? ? parsed : nil
            end
          end.compact
        elsif value.is_a?(Array)
          value.map do |v|
            if v.is_a?(String) && (v.downcase == 'no min' || v.downcase == 'no max')
              v.downcase == 'no min' ? 'No min' : 'No max'
            else
              parsed = v.to_i
              parsed.positive? ? parsed : nil
            end
          end.compact
        end
      end

      # Parse options for bedroom/bathroom dropdowns
      def parse_options(value)
        return nil if value.blank?

        if value.is_a?(String)
          value.split(',').map(&:strip).map do |opt|
            # Keep "Any" and "6+" as strings, convert numbers
            opt.match?(/^\d+$/) ? opt.to_i : opt
          end
        elsif value.is_a?(Array)
          value.map do |opt|
            opt.to_s.match?(/^\d+$/) ? opt.to_i : opt.to_s
          end
        end
      end

      # Build locale details for the website's supported locales
      # Uses Pwb::Config for centralized locale configuration
      def build_website_locales
        supported = @website.supported_locales || ['en']
        Pwb::Config.build_locale_details(supported)
      end
    end
  end
end
