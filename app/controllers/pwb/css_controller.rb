module Pwb
  class CssController < ActionController::Base
    # renders a stylesheet with client configured variables
    def custom_css
      @current_website = Website.unique_instance
      # @carousel_items = Content.where(tag: "landing-carousel").includes(:content_photos, :translations)
      return render "pwb/custom_css/#{@current_website.theme_name}", formats: :css
    end
  end

end
