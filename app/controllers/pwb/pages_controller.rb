require_dependency 'pwb/application_controller'

module Pwb
  class PagesController < ApplicationController
    before_action :header_image_url

    def show_page
      default_page_slug = "home"
      page_slug = params[:page_slug] || default_page_slug
      @page = Pwb::Page.find_by_slug page_slug
      if @page.blank?
        @page = Pwb::Page.find_by_slug default_page_slug
      end

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
      # @title_key = @page.link_key
      # @page_title = I18n.t(@page.link_key)
      render "/pwb/pages/show"
    end

    private

    def header_image_url
      # used by berlin theme
      @header_image_url = Content.where(tag: 'landing-carousel')[0].default_photo_url
    end
  end
end
