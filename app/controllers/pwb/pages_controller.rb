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


      visible_page_fragments = @page.details["visiblePageParts"]
      @content_to_show = []

      # TODO - order below:
      visible_page_fragments.each do |page_fragment_label|
        unless page_fragment_label == "raw_html"
          # fragment_html = @page.raw_html
          fragment_html = @page.get_fragment_html page_fragment_label, I18n.locale.to_s
          @content_to_show.push fragment_html
        end
      end

      # cmsparts_info = @page.details["cmsPartsList"] || []
      # @content_to_show = []
      # # TODO - order below:
      # cmsparts_info.each do |cmspart_info|
      #   cmspart_label = cmspart_info["label"]
      #   comfy_page = Comfy::Cms::Page.where(label: cmspart_label, slug: locale).first
      #   if comfy_page.present?
      #     @content_to_show.push comfy_page.content_cache
      #     # cmspart_info["content_cache"] = comfy_page.content_cache
      #   end
      # end
      # @title_key = @page.link_key
      # @page_title = I18n.t(@page.link_key)
      render "/pwb/pages/show"
    end

    private

    def header_image_url
      lc_content = Content.where(tag: 'landing-carousel')[0]
      # used by berlin theme
      @header_image_url = lc_content.present? ? lc_content.default_photo_url : nil
    end
  end
end
