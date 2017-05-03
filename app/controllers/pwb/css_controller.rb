module Pwb
  class CssController < ActionController::Base
    # renders a stylesheet with client configured variables
    def custom_css
      @current_website = Website.unique_instance
      theme_name = @current_website.theme_name.present? ? @current_website.theme_name : "default"
      # @carousel_items = Content.where(tag: "landing-carousel").includes(:content_photos, :translations)
      return render "pwb/custom_css/#{theme_name}", formats: :css
    end
  end

end
