module Pwb
  class CssController < ActionController::Base
    # renders a stylesheet with client configured variables
    def agency_css
      @current_website = Website.unique_instance
      # @carousel_items = Content.where(tag: "landing-carousel").includes(:content_photos, :translations)
      return render "pwb/css/#{@current_website.custom_css_file}", formats: :css
    end
  end

end
