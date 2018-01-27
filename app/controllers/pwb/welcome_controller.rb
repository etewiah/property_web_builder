require_dependency 'pwb/application_controller'

module Pwb
  class WelcomeController < ApplicationController
    before_action :header_image_url

    def index
      @page = Pwb::Page.find_by_slug "home"
      @page_title = @current_agency.company_name
      # @content_to_show = []

      if @page.present?
        if @page.page_title.present?
          @page_title = @page.page_title + ' - ' + @current_agency.company_name.to_s
        end

        @properties_for_sale = Prop.for_sale.visible.order('highlighted DESC').limit 9
        @properties_for_rent = Prop.for_rent.visible.order('highlighted DESC').limit 9

        # @search_defaults = params[:search].present? ? params[:search] : {}

        return render "pwb/welcome/index"
      else
        return render "pwb/page_not_found"
      end
    end

    private

    def header_image_url
      # lc_content = Content.where(tag: 'landing-carousel')[0]
      lc_photo = ContentPhoto.find_by_block_key "landing_img"
      # used by berlin theme
      @header_image_url = lc_photo.present? ? lc_photo.optimized_image_url : nil
    end
  end
end
