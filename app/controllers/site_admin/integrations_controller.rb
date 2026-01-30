# frozen_string_literal: true

module SiteAdmin
  # Controller for managing website integrations (AI, CRM, etc.)
  #
  # Provides CRUD operations for external service integrations,
  # including connection testing and credential management.
  class IntegrationsController < ::SiteAdminController
    before_action :set_integration, only: %i[show edit update destroy test_connection toggle]

    def index
      @integrations_by_category = current_website.integrations.group_by(&:category)
      @available_providers = build_available_providers
    end

    def show
      respond_to do |format|
        format.html
        format.json { render json: integration_json(@integration) }
      end
    end

    def new
      @category = params[:category]
      @provider = params[:provider]

      unless valid_provider?(@category, @provider)
        redirect_to site_admin_integrations_path, alert: 'Invalid integration provider'
        return
      end

      @provider_definition = Integrations::Registry.provider(@category, @provider)
      @integration = current_website.integrations.build(
        category: @category,
        provider: @provider
      )
    end

    def create
      @integration = current_website.integrations.build(integration_params)

      # Set credentials from nested params
      set_credentials_from_params

      # Set settings from nested params
      set_settings_from_params

      if @integration.save
        redirect_to site_admin_integrations_path,
                    notice: "#{@integration.provider_name} integration configured successfully"
      else
        @category = @integration.category
        @provider = @integration.provider
        @provider_definition = @integration.provider_definition
        flash.now[:alert] = @integration.errors.full_messages.join(', ')
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @category = @integration.category
      @provider = @integration.provider
      @provider_definition = @integration.provider_definition
    end

    def update
      # Set credentials from nested params (only if provided)
      set_credentials_from_params

      # Set settings from nested params
      set_settings_from_params

      # Update basic attributes
      @integration.enabled = params.dig(:integration, :enabled) != '0' if params.dig(:integration, :enabled)

      if @integration.save
        redirect_to site_admin_integrations_path,
                    notice: "#{@integration.provider_name} integration updated successfully"
      else
        @category = @integration.category
        @provider = @integration.provider
        @provider_definition = @integration.provider_definition
        flash.now[:alert] = @integration.errors.full_messages.join(', ')
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      provider_name = @integration.provider_name
      @integration.destroy
      redirect_to site_admin_integrations_path,
                  notice: "#{provider_name} integration removed"
    end

    def test_connection
      result = @integration.test_connection

      respond_to do |format|
        format.html do
          if result
            redirect_to site_admin_integrations_path,
                        notice: "#{@integration.provider_name} connection successful!"
          else
            redirect_to site_admin_integrations_path,
                        alert: "Connection failed: #{@integration.last_error_message}"
          end
        end
        format.json do
          if result
            render json: { success: true, message: 'Connection successful' }
          else
            render json: { success: false, message: @integration.last_error_message },
                   status: :unprocessable_entity
          end
        end
      end
    end

    def toggle
      @integration.update(enabled: !@integration.enabled?)

      respond_to do |format|
        format.html do
          status = @integration.enabled? ? 'enabled' : 'disabled'
          redirect_to site_admin_integrations_path,
                      notice: "#{@integration.provider_name} #{status}"
        end
        format.json do
          render json: { enabled: @integration.enabled? }
        end
      end
    end

    private

    def set_integration
      @integration = current_website.integrations.find(params[:id])
    end

    def integration_params
      params.require(:integration).permit(:category, :provider, :enabled)
    end

    def set_credentials_from_params
      return unless params[:credentials].present?

      params[:credentials].each do |key, value|
        # Skip blank values and placeholder values (masked credentials)
        next if value.blank? || value.start_with?('••••')

        @integration.set_credential(key, value)
      end
    end

    def set_settings_from_params
      return unless params[:settings].present?

      params[:settings].each do |key, value|
        @integration.set_setting(key, value)
      end
    end

    def valid_provider?(category, provider)
      return false if category.blank? || provider.blank?

      Integrations::Registry.provider(category, provider).present?
    end

    def build_available_providers
      result = {}

      Pwb::WebsiteIntegration::CATEGORIES.each do |category, info|
        providers = Integrations::Registry.providers_for(category)
        next if providers.empty?

        result[category] = {
          info: info,
          providers: providers.map do |provider_key, provider_class|
            existing = current_website.integrations.find_by(category: category, provider: provider_key)
            {
              key: provider_key,
              definition: provider_class,
              integration: existing
            }
          end
        }
      end

      result
    end

    def integration_json(integration)
      {
        id: integration.id,
        category: integration.category,
        provider: integration.provider,
        provider_name: integration.provider_name,
        enabled: integration.enabled?,
        status: integration.status,
        status_label: integration.status_label,
        last_used_at: integration.last_used_at,
        last_error_at: integration.last_error_at,
        last_error_message: integration.last_error_message,
        settings: integration.settings,
        # Never expose actual credentials - only masked versions
        credentials: integration.provider_definition&.credential_fields&.keys&.each_with_object({}) do |key, hash|
          hash[key] = integration.masked_credential(key)
        end
      }
    end
  end
end
