require_dependency 'pwb/application_controller'

module Pwb
  class PagesController < ApplicationController
    include SeoHelper
    include HttpCacheable

    before_action :header_image_url
    before_action :extract_lcp_image, only: [:show_page]

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

        # Set SEO for the page
        set_page_seo(@page)

        # HTTP caching for pages - cache for 10 minutes, stale for 1 hour
        set_cache_control_headers(
          max_age: 10.minutes,
          public: true,
          stale_while_revalidate: 1.hour
        )
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
      # used for header background images
      @header_image_url = lc_photo.present? ? lc_photo.optimized_image_url : nil
    end

    # Extract LCP (Largest Contentful Paint) image from page content
    # for preloading in the <head> to improve page load performance.
    # Looks for hero page parts which typically contain the LCP image.
    def extract_lcp_image
      @lcp_image_url = nil
      page_slug = params[:page_slug] || "home"
      page = @current_website.pages.find_by_slug(page_slug)
      return unless page

      # Find the first hero page part on this page
      hero_page_part = find_hero_page_part(page)
      return unless hero_page_part

      # Extract background_image from block_contents
      locale = I18n.locale.to_s
      blocks = hero_page_part.block_contents&.dig(locale, "blocks")
      blocks ||= hero_page_part.block_contents&.dig("en", "blocks") # fallback to English

      @lcp_image_url = blocks&.dig("background_image", "content")
      @lcp_image_url ||= blocks&.dig("image", "content") # fallback for hero_split
    end

    def find_hero_page_part(page)
      # Get visible page contents ordered by sort_order
      hero_keys = %w[heroes/hero_centered heroes/hero_search heroes/hero_split]

      page.page_contents.ordered_visible.each do |page_content|
        next if page_content.is_rails_part

        if hero_keys.include?(page_content.page_part_key)
          return Pwb::PagePart.find_by(
            website_id: @current_website.id,
            page_part_key: page_content.page_part_key
          )
        end
      end

      nil
    end
  end
end
