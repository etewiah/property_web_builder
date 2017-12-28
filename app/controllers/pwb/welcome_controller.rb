require_dependency 'pwb/application_controller'

module Pwb
  class WelcomeController < ApplicationController
    before_action :header_image_url

    def index
      @page = Pwb::Page.find_by_slug "home"
      @page_title = @current_agency.company_name
      @content_to_show = []

      if @page.present?
        if @page.page_title.present?
          @page_title = @page.page_title + ' - ' + @current_agency.company_name.to_s
        end
        # TODO - move below into a service class
        @composed_content = @page.compose_contents
        # @page.ordered_visible_page_contents.each do |page_content|
        #   @content_to_show.push page_content.get_html_or_page_part_key
        #   # @content_to_show.push page_content.content.raw
        # end
        # @carousel_items = Content.where(tag: 'landing-carousel')
        # @carousel_speed = 3000
        # @content_area_cols = Content.where(tag: 'content-area-cols').order('sort_order')

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
