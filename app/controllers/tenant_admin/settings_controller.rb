# frozen_string_literal: true

module TenantAdmin
  class SettingsController < TenantAdminController
    def show
      @tenant_settings = Pwb::TenantSettings.instance
      @all_themes = Pwb::Theme.enabled
      @selected_themes = @tenant_settings.effective_default_themes
    end

    def update
      @tenant_settings = Pwb::TenantSettings.instance

      # Get submitted theme names, ensuring we always keep default
      theme_names = params.dig(:tenant_settings, :default_available_themes) || []
      theme_names = theme_names.reject(&:blank?)

      # Ensure 'default' theme is always included
      theme_names = (['default'] + theme_names).uniq

      if @tenant_settings.update(default_available_themes: theme_names)
        redirect_to tenant_admin_settings_path, notice: 'Tenant settings updated successfully.'
      else
        @all_themes = Pwb::Theme.enabled
        @selected_themes = theme_names
        flash.now[:alert] = 'Failed to update settings.'
        render :show, status: :unprocessable_entity
      end
    end
  end
end
