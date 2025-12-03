module Pwb
  class EditorController < ApplicationController
    # Use a minimal layout for the editor shell
    layout false
    
    # Skip theme path setup since editor has its own layout
    skip_before_action :set_theme_path

    # TODO: Re-enable authentication before production
    # Ensure only admins can access the editor
    # before_action :authenticate_admin_user!

    def show
      # The path to load in the iframe (defaults to root)
      path = params[:path] ? "/#{params[:path]}" : root_path
      path = "/#{path}" unless path.start_with?("/")
      
      # Append edit_mode param
      separator = path.include?("?") ? "&" : "?"
      @iframe_path = "#{path}#{separator}edit_mode=true"
    end

    private

    def authenticate_admin_user!
      # Re-use existing admin authentication logic
      unless current_user && current_user.admin?
        flash[:alert] = "You are not authorized to access this page."
        redirect_to root_path
      end
    end
  end
end
