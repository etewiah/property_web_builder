module Pwb
  class CssController < ActionController::Base
    def agency_css
      @current_agency ||= (Agency.last || Agency.create)
      # @carousel_items = Content.where(tag: "landing-carousel").includes(:content_photos, :translations)

      return render "pwb/css/#{@current_agency.custom_css_file}", formats: :css
    end
  end

end
