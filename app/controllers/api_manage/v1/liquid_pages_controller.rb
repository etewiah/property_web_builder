# frozen_string_literal: true

module ApiManage
  module V1
    # Returns page data with Liquid templates and block_contents for client-side rendering
    #
    # This endpoint provides all data needed to render AND EDIT a page on the client side,
    # including the Liquid template and variables (block_contents) for each page part,
    # plus all SEO metadata from the localized_pages endpoint.
    #
    # This is a SUPERSET of api_public/v1/localized_page - it includes everything from
    # that endpoint plus additional content management data:
    # - liquid_part_template for each page part
    # - block_contents (editable variables)
    # - field_schema for editor UI
    # - available_locales per page part
    # - edit_key for each page content
    # - ALL page contents (not just visible ones)
    #
    # Use this endpoint when you need to:
    # - Render templates client-side (e.g., in Astro.js)
    # - Build an editor that modifies block_contents
    # - Have full control over template rendering
    # - Access SEO metadata for preview
    #
    # This is the api_manage version - no caching, for admin/editing use.
    #
    class LiquidPagesController < BaseController
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
          # === Core page data ===
          id: page.id,
          slug: page.slug,
          locale: locale,
          title: page.seo_title.presence || page.page_title.presence || page.slug.titleize,
          meta_description: page.meta_description,
          meta_keywords: page.meta_keywords,
          last_modified: page.updated_at.iso8601,

          # === SEO metadata (from localized_pages) ===
          canonical_url: build_canonical_url(page),
          og: build_open_graph(page, website),
          twitter: build_twitter_card(page, website),
          json_ld: build_json_ld(page, website),
          breadcrumbs: build_breadcrumbs(page),
          alternate_locales: build_alternate_locales(page),

          # === Navigation metadata ===
          sort_order_top_nav: page.sort_order_top_nav,
          show_in_top_nav: page.show_in_top_nav,
          sort_order_footer: page.sort_order_footer,
          show_in_footer: page.show_in_footer,
          visible: page.visible,

          # === Content management data (unique to api_manage) ===
          page_contents: build_liquid_page_contents(page, locale)
        }
      end

      def build_liquid_page_contents(page, locale)
        return [] unless page.respond_to?(:page_contents)

        # Use all page_contents (not just visible) for management API
        # Admins need to see hidden content to toggle visibility and edit before publishing
        page.page_contents.ordered.includes(:content).map do |page_content|
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
          "page_slug" => page_slug,
          "edit_key" => "#{page_slug}::#{page_part_key}",
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
          # Field schema with full metadata for editor UI
          "field_schema" => build_field_schema(page_part_key)
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
          Rails.logger.info "[ApiManage::LiquidPages] Auto-created PagePart '#{page_part_key}' for page '#{page_slug}' website #{website.id}"
        end

        page_part
      end

      # Initialize a new PagePart with default block_contents from PagePartLibrary
      def initialize_page_part_from_library(page_part, page_part_key)
        definition = Pwb::PagePartLibrary.definition(page_part_key)
        fields_config = definition&.dig(:fields)

        blocks = {}

        # Handle both array (legacy) and hash (modern) field definitions
        if fields_config.is_a?(Array)
          fields_config.each do |field_name|
            blocks[field_name.to_s] = { 'content' => '' }
          end
        elsif fields_config.is_a?(Hash)
          fields_config.each do |field_name, field_config|
            default_value = field_config[:default] || ''
            blocks[field_name.to_s] = { 'content' => default_value }
          end
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

      # Build field schema for editor UI using FieldSchemaBuilder
      # Returns full field metadata including types, validation, hints, and content guidance
      def build_field_schema(page_part_key)
        definition = Pwb::PagePartLibrary.definition(page_part_key)
        return nil unless definition

        fields_config = definition[:fields]
        return nil unless fields_config

        # Handle both array (legacy) and hash (modern) field definitions
        if fields_config.is_a?(Array)
          # Legacy format: array of field names, types inferred
          {
            'fields' => fields_config.map do |field_name|
              Pwb::FieldSchemaBuilder.build_field_definition(field_name, {})
            end,
            'groups' => []
          }
        else
          # Modern format: hash with explicit field configurations
          field_groups = definition[:field_groups] || {}
          {
            'fields' => fields_config.map do |field_name, field_config|
              Pwb::FieldSchemaBuilder.build_field_definition(field_name, field_config || {})
            end,
            'groups' => field_groups.map do |key, config|
              {
                'key' => key.to_s,
                'label' => config[:label] || key.to_s.humanize,
                'order' => config[:order] || 999
              }
            end.sort_by { |g| g['order'] }
          }
        end
      end

      # ========================================
      # SEO Metadata helpers (from LocalizedPagesController)
      # ========================================

      def build_canonical_url(page)
        host = request.host_with_port
        protocol = request.protocol
        path = build_page_path(page, I18n.locale)

        "#{protocol}#{host}#{path}"
      end

      def build_page_path(page, locale)
        default_locale = default_website_locale

        if locale.to_s == default_locale.to_s
          "/p/#{page.slug}"
        else
          "/#{locale}/p/#{page.slug}"
        end
      end

      def default_website_locale
        Pwb::Current.website&.default_client_locale&.to_s || "en"
      end

      def build_open_graph(page, website)
        site_name = website.company_display_name.presence ||
                    website.agency&.display_name.presence ||
                    "Property Website"

        og = {
          "og:title" => page.seo_title.presence || page.page_title.presence || page.slug.titleize,
          "og:description" => page.meta_description.presence || website_default_description(website),
          "og:type" => "website",
          "og:url" => build_canonical_url(page),
          "og:site_name" => site_name
        }

        # Add og:image if available from page or website
        og_image = page_og_image(page) || website_logo(website)
        og["og:image"] = og_image if og_image.present?

        og.compact
      end

      def build_twitter_card(page, website)
        {
          "twitter:card" => "summary_large_image",
          "twitter:title" => page.seo_title.presence || page.page_title.presence || page.slug.titleize,
          "twitter:description" => page.meta_description.presence || website_default_description(website),
          "twitter:image" => page_og_image(page) || website_logo(website)
        }.compact
      end

      def build_json_ld(page, website)
        site_name = website.company_display_name.presence ||
                    website.agency&.display_name.presence ||
                    "Property Website"

        json_ld = {
          "@context" => "https://schema.org",
          "@type" => "WebPage",
          "name" => page.seo_title.presence || page.page_title.presence || page.slug.titleize,
          "description" => page.meta_description,
          "url" => build_canonical_url(page),
          "inLanguage" => I18n.locale.to_s,
          "datePublished" => page.created_at&.to_date&.iso8601,
          "dateModified" => page.updated_at&.to_date&.iso8601,
          "publisher" => build_publisher_json_ld(site_name, website)
        }

        json_ld.compact
      end

      def build_publisher_json_ld(site_name, website)
        publisher = {
          "@type" => "Organization",
          "name" => site_name
        }

        logo_url = website_logo(website)
        if logo_url.present?
          publisher["logo"] = {
            "@type" => "ImageObject",
            "url" => logo_url
          }
        end

        publisher
      end

      def build_breadcrumbs(page)
        locale = I18n.locale
        default_locale = default_website_locale

        home_url = locale.to_s == default_locale ? "/" : "/#{locale}/"
        page_url = build_page_path(page, locale)

        [
          { "name" => I18n.t("breadcrumbs.home", default: "Home"), "url" => home_url },
          { "name" => page.page_title.presence || page.slug.titleize, "url" => page_url }
        ]
      end

      def build_alternate_locales(page)
        website = Pwb::Current.website
        supported_locales = website.supported_locales || [default_website_locale]
        current_base_locale = normalize_locale_for_mobility(I18n.locale)&.to_s

        supported_locales.filter_map do |locale|
          # Normalize for comparison to handle "es" vs "es-MX"
          locale_base = normalize_locale_for_mobility(locale)&.to_s
          next if locale_base == current_base_locale

          # Use the base locale for the URL path
          path = build_page_path(page, locale_base || locale)
          url = "#{request.protocol}#{request.host_with_port}#{path}"

          { "locale" => locale_base || locale.to_s, "url" => url }
        end
      end

      # Normalize regional locale codes to base codes for Mobility
      # e.g., "en-US" → :en, "es-MX" → :es
      def normalize_locale_for_mobility(locale)
        return nil if locale.blank?

        base_locale = locale.to_s.split('-').first.to_sym
        # Only return if it's a valid Mobility/I18n locale
        I18n.available_locales.include?(base_locale) ? base_locale : nil
      end

      def website_default_description(website)
        website.default_meta_description.presence || "Find your dream property"
      end

      def website_logo(website)
        return nil unless website.respond_to?(:logo_url)
        website.logo_url.presence
      end

      def page_og_image(page)
        # Check if page has a custom OG image in its details or translations
        return nil unless page.respond_to?(:details) && page.details.is_a?(Hash)
        page.details["og_image_url"].presence
      end
    end
  end
end
