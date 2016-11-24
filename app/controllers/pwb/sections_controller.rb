require_dependency 'pwb/application_controller'

module Pwb
  class SectionsController < ApplicationController

    # def sell
    #   # @agency = Agency.find_by_subdomain(request.subdomain.downcase)
    #   @enquiry = Message.new
    # end

    # def rent
    #   @enquiry = Message.new
    # end

    def about_us
      @content = Content.find_by_key("aboutUs")
      @page_title = I18n.t("aboutUs")
      @page_description = @content.raw
      # @page_keywords    = 'Site, Login, Members'
      # @about_us_image_url = Content.get_photo_url_by_key("aboutUs")
      # @about_us_image_url = Content.find_by_key("aboutUs").content_photos.first.image_url || "http://moodleboard.com/images/prv/estate/estate-slider-bg-1.jpg"
      return render "/pwb/themes/standard/sections/about_us"
    end

    def privacy_policy
      @title_key = "privacyPolicy"
      @page_title = I18n.t("privacyPolicy")
      @content = Content.find_by_key("privacyPolicy")
      return render @current_tenant.views_folder + "/sections/static"
    end

    def legal
      @title_key = "legalAdvice"
      @page_title = I18n.t("legalAdvice")
      @content = Content.find_by_key("legalAdvice")
      return render @current_tenant.views_folder + "/sections/static"
    end
  end
end
