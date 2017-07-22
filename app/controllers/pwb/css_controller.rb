module Pwb
  class CssController < ActionController::Base
    # renders a stylesheet with client configured variables
    def custom_css
      @current_website = Website.unique_instance
      theme_name = params[:theme_name] || default
      render "pwb/custom_css/#{theme_name}", formats: :css
    end
  end
end
