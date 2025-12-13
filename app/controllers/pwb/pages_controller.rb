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
          if page_content.is_rails_part
            # Rails parts are rendered as partials in the view, skip content extraction
            @content_to_show.push nil
          else
            @content_to_show.push page_content.content&.raw
          end
          # Store page_content objects for edit mode
          @page_contents_for_edit.push page_content
        end
      end

      render "/pwb/pages/show"
    end

    # Renders a single page part from a page.
    # URL: /p/:page_slug/:page_part_key
    # Useful for previewing or embedding individual content sections.
    def show_page_part
      page_slug = params[:page_slug]
      page_part_key = params[:page_part_key]

      @page = @current_website.pages.find_by_slug(page_slug)
      if @page.blank?
        render plain: "Page not found: #{page_slug}", status: :not_found
        return
      end

      # Find the page content for this page part
      @page_content = @page.page_contents.find_by(page_part_key: page_part_key)
      if @page_content.blank? || !@page_content.visible_on_page
        render plain: "Page part not found or not visible: #{page_part_key}", status: :not_found
        return
      end

      @page_part_key = page_part_key
      @is_rails_part = @page_content.is_rails_part
      @content_html = @is_rails_part ? nil : @page_content.content&.raw

      render "/pwb/pages/show_page_part", layout: "pwb/page_part"
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
