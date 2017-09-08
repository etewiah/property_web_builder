module Pwb
  class CssController < ActionController::Base
    # renders a stylesheet with client configured variables
    # - spt 2017 - currently only used by devise layout
    # other layout directly render partial via helper method
    def custom_css
      @bg_style_vars = []
      @text_color_style_vars = []
      @current_website = Website.unique_instance
      theme_name = params[:theme_name] || default
      render "pwb/custom_css/#{theme_name}", formats: :css
    end
  end
end
