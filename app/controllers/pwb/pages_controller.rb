require_dependency 'pwb/application_controller'

module Pwb
  class PagesController < ApplicationController
    before_action :header_image_url

    def show_page
      default_page_slug = "home"
      page_slug = params[:page_slug] || default_page_slug
      @page = @current_website.pages.find_by_slug page_slug
      if @page.blank?
        @page = @current_website.pages.find_by_slug default_page_slug
      end
      @content_to_show = []
      @page_contents_for_edit = []

      # @page.ordered_visible_contents.each do |page_content|
      # above does not get ordered correctly
      if @page.present?
        @page.ordered_visible_page_contents.each do |page_content|
          @content_to_show.push page_content.content.raw
          # Store page_content objects for edit mode
          @page_contents_for_edit.push page_content
        end
      end

      render "/pwb/pages/show"
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
