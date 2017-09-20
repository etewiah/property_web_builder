require_dependency 'pwb/application_controller'

module Pwb
  class WelcomeController < ApplicationController
    def index
      @page = Pwb::Page.find_by_slug "home"

      # visible_page_fragment_names = @page.present? ? @page.details["visiblePageParts"] : []
      @content_to_show = []

      @page.ordered_visible_contents.each do |page_content|
        @content_to_show.push page_content.raw
      end
      # visible_page_fragment_names.each do |page_fragment_label|
      #   unless page_fragment_label == "raw_html"
      #     # fragment_html = @page.raw_html
      #     fragment_html = @page.get_fragment_html page_fragment_label, I18n.locale.to_s
      #     @content_to_show.push fragment_html
      #   end
      # end

      @carousel_items = Content.where(tag: 'landing-carousel')
      @carousel_speed = 3000
      # .includes(:content_photos, :translations)
      @content_area_cols = Content.where(tag: 'content-area-cols').order('sort_order')
      # @about_us = Content.find_by_key('aboutUs')
      @properties_for_sale = Prop.for_sale.visible.order('highlighted DESC').limit 9
      @properties_for_rent = Prop.for_rent.visible.order('highlighted DESC').limit 9

      @search_defaults = params[:search].present? ? params[:search] : {}

      render "pwb/welcome/index"
    end
  end
end
