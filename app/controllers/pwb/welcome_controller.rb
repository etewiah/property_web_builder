require_dependency 'pwb/application_controller'

module Pwb
  class WelcomeController < ApplicationController
    before_action :header_image_url

    def index
      @page = Pwb::Page.find_by_slug "home"

      # visible_page_fragment_names = @page.present? ? @page.details["visiblePageParts"] : []
      @content_to_show = []

      # @page.ordered_visible_contents.each do |page_content|
      # above does not get ordered correctly
      if @page.present?
        @page.ordered_visible_page_contents.each do |page_content|
          @content_to_show.push page_content.content.raw
        end
      end
      # @carousel_items = Content.where(tag: 'landing-carousel')
      # @carousel_speed = 3000
      # @content_area_cols = Content.where(tag: 'content-area-cols').order('sort_order')

      @properties_for_sale = Prop.for_sale.visible.order('highlighted DESC').limit 9
      @properties_for_rent = Prop.for_rent.visible.order('highlighted DESC').limit 9

      @search_defaults = params[:search].present? ? params[:search] : {}

      render "pwb/welcome/index"
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
