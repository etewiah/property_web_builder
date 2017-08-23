require_dependency 'pwb/application_controller'

module Pwb
  class WelcomeController < ApplicationController
    def index
      @page = Pwb::Page.find_by_slug "home"

      cmsparts_info = @page.details["cmsPartsList"] || []
      @content_to_show = []
      # TODO - order below:
      cmsparts_info.each do |cmspart_info|
        cmspart_label = cmspart_info["label"]
        comfy_page = Comfy::Cms::Page.where(label: cmspart_label, slug: locale).first
        if comfy_page.present?
          @content_to_show.push comfy_page.content_cache
          # cmspart_info["content_cache"] = comfy_page.content_cache
        end
      end

      
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
