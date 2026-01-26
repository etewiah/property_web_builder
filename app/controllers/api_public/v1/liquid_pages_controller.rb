# frozen_string_literal: true

module ApiPublic
  module V1
    # Returns page data with Liquid templates and block_contents for client-side rendering
    #
    # This endpoint provides all data needed to render a page on the client side,
    # including the Liquid template and variables (block_contents) for each page part.
    #
    # Use this endpoint when you need to:
    # - Render templates client-side (e.g., in Astro.js)
    # - Build an editor that modifies block_contents
    # - Have full control over template rendering
    #
    # For pre-rendered HTML, use the localized_pages endpoint instead.
    #
    class LiquidPagesController < BaseController
      include ApiPublic::Cacheable
      include UrlLocalizationHelper

      def show
        setup_locale

        unless website_provisioned?
          render json: website_not_provisioned_error, status: :not_found
          return
        end

        page = Pwb::Current.website.pages.find_by(slug: params[:page_slug])

        unless page
          render json: page_not_found_error, status: :not_found
          return
        end

        set_short_cache(max_age: 5.minutes, etag_data: [page.id, page.updated_at, I18n.locale, 'liquid'])
        return if performed?

        render json: build_liquid_page_response(page)
      end

      private

      def setup_locale
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale.to_sym
      end

      def website_provisioned?
        Pwb::Current.website.present? && Pwb::Current.website.pages.exists?
      end

      def website_not_provisioned_error
        {
          error: "Website not provisioned",
          message: "The website has not been provisioned with any pages.",
          code: "WEBSITE_NOT_PROVISIONED"
        }
      end

      def page_not_found_error
        {
          error: "Page not found",
          code: "PAGE_NOT_FOUND"
        }
      end

      def build_liquid_page_response(page)
        website = Pwb::Current.website
        locale = I18n.locale.to_s

        {
          id: page.id,
          slug: page.slug,
          locale: locale,
          title: page.seo_title.presence || page.page_title.presence || page.slug.titleize,
          meta_description: page.meta_description,
          meta_keywords: page.meta_keywords,
          last_modified: page.updated_at.iso8601,
          page_contents: build_liquid_page_contents(page, locale)
        }
      end

      def build_liquid_page_contents(page, locale)
        return [] unless page.respond_to?(:ordered_visible_page_contents)

        page.ordered_visible_page_contents.map do |page_content|
          build_liquid_content_item(page_content, page.slug, locale)
        end
      end

      def build_liquid_content_item(page_content, page_slug, locale)
        page_part_key = page_content.page_part_key
        page_part = find_or_create_page_part(page_part_key, page_slug)

        # Get rendered HTML for fallback
        raw_html = page_content.is_rails_part ? nil : page_content.content&.raw
        localized_html = raw_html.present? ? localize_html_urls(raw_html) : nil

        # Get block_contents for the requested locale (with fallback)
        block_contents = extract_block_contents(page_part, locale)

        # Get template content
        template = page_part&.template_content

        # Get field definitions from PagePartLibrary
        definition = Pwb::PagePartLibrary.definition(page_part_key)

        {
          "page_part_key" => page_part_key,
          "sort_order" => page_content.sort_order,
          "visible" => page_content.visible_on_page,
          "is_rails_part" => page_content.is_rails_part || false,
          "label" => page_content.label,
          # Pre-rendered HTML (for fallback or direct use)
          "rendered_html" => localized_html,
          # Liquid template for client-side rendering
          "liquid_part_template" => template,
          # Block contents (variables) for the requested locale
          "block_contents" => block_contents,
          # All locales available for this page part
          "available_locales" => page_part&.block_contents&.keys || [],
          # Field definitions from library (for editor UI)
          "field_definitions" => build_field_definitions(definition)
        }
      end

      # Find existing PagePart with page_slug priority, or create one with defaults from library
      # Priority: 1) Page-specific (page_part_key + page_slug), 2) Website-wide (page_part_key only)
      def find_or_create_page_part(page_part_key, page_slug)
        website = Pwb::Current.website
        return nil unless website

        # First try to find page-specific PagePart
        page_part = Pwb::PagePart.find_by(
          website_id: website.id,
          page_part_key: page_part_key,
          page_slug: page_slug
        )

        # Fall back to website-wide PagePart (page_slug nil or empty)
        page_part ||= Pwb::PagePart.where(website_id: website.id, page_part_key: page_part_key)
                                   .where(page_slug: [nil, ''])
                                   .first

        # Auto-create if nothing exists
        if page_part.nil?
          page_part = Pwb::PagePart.new(
            website_id: website.id,
            page_part_key: page_part_key,
            page_slug: page_slug
          )
          initialize_page_part_from_library(page_part, page_part_key)
          page_part.save
          Rails.logger.info "[LiquidPages] Auto-created PagePart '#{page_part_key}' for page '#{page_slug}' website #{website.id}"
        end

        page_part
      end

      # Initialize a new PagePart with default block_contents from PagePartLibrary
      def initialize_page_part_from_library(page_part, page_part_key)
        definition = Pwb::PagePartLibrary.definition(page_part_key)
        fields = definition&.dig(:fields) || []

        blocks = {}
        fields.each do |field_name|
          blocks[field_name] = { 'content' => '' }
        end

        default_locale = I18n.default_locale.to_s
        page_part.block_contents = {
          default_locale => { 'blocks' => blocks }
        }
        page_part.show_in_editor = true
      end

      # Extract block_contents for a specific locale with fallback
      def extract_block_contents(page_part, locale)
        return nil unless page_part&.block_contents

        block_contents = page_part.block_contents

        # Try requested locale first
        if block_contents[locale].present?
          return block_contents[locale]
        end

        # Try base locale (e.g., "es" if "es-MX" was requested)
        base_locale = locale.split('-').first
        if base_locale != locale && block_contents[base_locale].present?
          return block_contents[base_locale]
        end

        # Fallback to English
        if block_contents['en'].present?
          return block_contents['en']
        end

        # Fallback to first available locale
        block_contents.values.first
      end

      # Build field definitions for editor UI
      def build_field_definitions(definition)
        return nil unless definition

        fields = definition[:fields] || []

        fields.map do |field_name|
          {
            "name" => field_name,
            "type" => infer_field_type(field_name),
            "label" => field_name.humanize
          }
        end
      end

      # Infer field type from field name
      def infer_field_type(field_name)
        name = field_name.to_s.downcase

        if name.include?('image') || name.include?('photo') || name.include?('src') || name.include?('background')
          'image'
        elsif name.include?('content') || name.include?('description') || name.include?('body') || name.include?('text')
          'textarea'
        elsif name.include?('link') || name.include?('url') || name.include?('href')
          'url'
        elsif name.include?('icon')
          'icon'
        elsif name.include?('color')
          'color'
        else
          'text'
        end
      end
    end
  end
end
