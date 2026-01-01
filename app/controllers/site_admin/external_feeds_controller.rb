# frozen_string_literal: true

module SiteAdmin
  # Controller for managing external feed configuration.
  # Allows website admins to configure third-party property feed integrations
  # such as Resales Online for displaying external listings.
  class ExternalFeedsController < ::SiteAdminController
    before_action :set_website

    def show
      @providers = available_providers
      @feed_status = feed_status_info
    end

    def update
      if @website.update(external_feed_params)
        # Clear cache when configuration changes
        @website.external_feed.invalidate_cache if @website.external_feed_enabled?

        redirect_to site_admin_external_feed_path,
                    notice: "External feed settings updated successfully"
      else
        @providers = available_providers
        @feed_status = feed_status_info
        flash.now[:alert] = "Failed to update external feed settings"
        render :show, status: :unprocessable_content
      end
    end

    def test_connection
      unless @website.external_feed_enabled?
        redirect_to site_admin_external_feed_path,
                    alert: "External feed is not enabled"
        return
      end

      feed = @website.external_feed

      begin
        if feed.enabled?
          # Try a simple search to verify connectivity
          result = feed.search(page: 1, per_page: 1)

          if result.error?
            redirect_to site_admin_external_feed_path,
                        alert: "Connection failed: #{result.error}"
          else
            redirect_to site_admin_external_feed_path,
                        notice: "Connection successful! Found #{result.total_count} properties."
          end
        else
          redirect_to site_admin_external_feed_path,
                      alert: "Provider is not available. Please check your configuration."
        end
      rescue StandardError => e
        Rails.logger.error("[ExternalFeeds] Test connection failed: #{e.message}")
        redirect_to site_admin_external_feed_path,
                    alert: "Connection test failed: #{e.message}"
      end
    end

    def clear_cache
      if @website.external_feed_enabled?
        @website.external_feed.invalidate_cache
        redirect_to site_admin_external_feed_path,
                    notice: "Cache cleared successfully"
      else
        redirect_to site_admin_external_feed_path,
                    alert: "External feed is not enabled"
      end
    end

    private

    def set_website
      @website = current_website
    end

    def external_feed_params
      # Permit the main settings
      permitted = params.require(:website).permit(
        :external_feed_enabled,
        :external_feed_provider
      )

      # Handle the config hash - convert to proper structure
      if params[:website][:external_feed_config].present?
        config_params = params[:website][:external_feed_config].to_unsafe_h
        # Filter out empty values and handle password masking
        config_params = config_params.reject { |_k, v| v.blank? || v == "••••••••••••" }

        # Merge with existing config to preserve unchanged secret values
        if @website.external_feed_config.present?
          existing_config = @website.external_feed_config
          config_params.each do |key, value|
            # Only update if not the placeholder
            existing_config[key] = value unless value == "••••••••••••"
          end
          permitted[:external_feed_config] = existing_config
        else
          permitted[:external_feed_config] = config_params
        end
      end

      permitted
    end

    def available_providers
      Pwb::ExternalFeed::Registry.available_providers.map do |name|
        provider_class = Pwb::ExternalFeed::Registry.find(name)
        {
          name: name,
          display_name: provider_class.display_name,
          config_fields: provider_config_fields(provider_class)
        }
      end
    end

    def provider_config_fields(provider_class)
      # Get required config keys from the provider
      # Create a dummy instance to access the protected method
      dummy = provider_class.allocate
      required = if dummy.respond_to?(:required_config_keys, true)
                   dummy.send(:required_config_keys)
                 else
                   []
                 end

      # Build field definitions based on provider type
      case provider_class.provider_name
      when :resales_online
        [
          {
            key: :api_key,
            label: "API Key",
            type: :password,
            required: required.include?(:api_key),
            help: "Your Resales Online API key"
          },
          {
            key: :api_id_sales,
            label: "API ID (Sales)",
            type: :text,
            required: required.include?(:api_id_sales),
            help: "API ID for sales listings"
          },
          {
            key: :api_id_rentals,
            label: "API ID (Rentals)",
            type: :text,
            required: false,
            help: "API ID for rental listings (optional, uses Sales ID if not set)"
          },
          {
            key: :p1_constant,
            label: "P1 Constant",
            type: :text,
            required: false,
            help: "P1 constant for API calls (optional, uses default if not set)"
          }
        ]
      else
        # Generic config fields for unknown providers
        required.map do |key|
          {
            key: key,
            label: key.to_s.titleize,
            type: :text,
            required: true,
            help: nil
          }
        end
      end
    end

    def feed_status_info
      return { configured: false, enabled: false } unless @website.external_feed_enabled?

      feed = @website.external_feed

      {
        configured: feed.configured?,
        enabled: feed.enabled?,
        provider_name: feed.provider_name,
        provider_display_name: feed.provider_display_name
      }
    rescue StandardError => e
      Rails.logger.error("[ExternalFeeds] Error getting feed status: #{e.message}")
      { configured: false, enabled: false, error: e.message }
    end
  end
end
