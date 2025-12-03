module Pwb
  class Editor::ThemeSettingsController < ApplicationController
    layout false
    # Skip theme path setup since we return JSON
    skip_before_action :set_theme_path
    skip_before_action :nav_links
    skip_before_action :footer_content
    # Skip CSRF for API calls
    skip_before_action :verify_authenticity_token, only: [:update]
    # TODO: Re-enable authentication before production
    # before_action :authenticate_admin_user!

    def show
      render json: {
        style_variables: @current_website.style_variables,
        theme_name: @current_website.theme_name
      }
    end

    def update
      if params[:style_variables].present?
        # Merge new style variables with existing ones
        current_vars = @current_website.style_variables || {}
        new_vars = style_variables_params.to_h
        
        merged_vars = current_vars.merge(new_vars)
        @current_website.style_variables = merged_vars
      end

      if @current_website.save
        render json: {
          status: "success",
          style_variables: @current_website.style_variables,
          message: "Theme settings saved successfully"
        }
      else
        render json: {
          status: "error",
          errors: @current_website.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    private

    def style_variables_params
      params.require(:style_variables).permit(
        :primary_color,
        :secondary_color,
        :action_color,
        :footer_bg_color,
        :footer_main_text_color,
        :labels_text_color,
        :body_style,
        :theme
      )
    end

    def authenticate_admin_user!
      unless current_user && current_user.admin?
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
