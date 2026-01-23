# frozen_string_literal: true

module ApiPublic
  module V1
    # Returns comprehensive localized page metadata for SEO and rendering
    #
    # This endpoint provides all data needed to render a page in a specific locale,
    # including SEO meta tags, Open Graph, Twitter Cards, JSON-LD structured data,
    # navigation info, and rendered page content.
    #
    # All text fields (title, meta_description, meta_keywords) are automatically
    # returned in the requested locale via Mobility translations.
    #
    class LocalizedPagesController < BaseController
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

        set_short_cache(max_age: 1.hour, etag_data: [page.id, page.updated_at, I18n.locale])
        return if performed?

        render json: build_localized_page_response(page)
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

      def build_localized_page_response(page)
        website = Pwb::Current.website

        {
          id: page.id,
          slug: page.slug,
          requester_locale: I18n.locale,
          requester_hostname: request.host,
          # Mobility-translated fields - automatically return current locale's value
          title: page.seo_title.presence || page.page_title.presence || page.slug.titleize,
          meta_description: page.meta_description,
          meta_keywords: page.meta_keywords,
          # Canonical URL is generated dynamically based on locale
          canonical_url: build_canonical_url(page),
          last_modified: page.updated_at.iso8601,
          etag: generate_page_etag(page),
          cache_control: "public, max-age=3600",
          og: build_open_graph(page, website),
          twitter: build_twitter_card(page, website),
          json_ld: build_json_ld(page, website),
          breadcrumbs: build_breadcrumbs(page),
          alternate_locales: build_alternate_locales(page),
          html_elements: build_html_elements(page),
          sort_order_top_nav: page.sort_order_top_nav,
          show_in_top_nav: page.show_in_top_nav,
          sort_order_footer: page.sort_order_footer,
          show_in_footer: page.show_in_footer,
          visible: page.visible,
          page_contents: build_page_contents(page)
        }
      end

      def generate_page_etag(page)
        "\"#{Digest::MD5.hexdigest("#{page.id}-#{page.updated_at}-#{I18n.locale}")}\""
      end

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

      def build_html_elements(page)
        # Return localized UI element labels for the page
        # These can be used by frontend frameworks that need pre-translated strings
        elements = []

        # Page title element
        elements << {
          "element_class_id" => "page_title",
          "element_label" => page.page_title.presence || page.slug.titleize
        }

        # Common form elements (if page has forms)
        elements << {
          "element_class_id" => "submit_button",
          "element_label" => I18n.t("buttons.submit", default: "Submit")
        }

        elements << {
          "element_class_id" => "back_button",
          "element_label" => I18n.t("buttons.back", default: "Back")
        }

        elements
      end

      # Get website's supported locales
      def website_supported_locales
        Pwb::Current.website&.supported_locales || I18n.available_locales.map(&:to_s)
      end

      # Normalize regional locale codes to base codes for Mobility
      # e.g., "en-US" → :en, "es-MX" → :es
      def normalize_locale_for_mobility(locale)
        return nil if locale.blank?

        base_locale = locale.to_s.split('-').first.to_sym
        # Only return if it's a valid Mobility/I18n locale
        I18n.available_locales.include?(base_locale) ? base_locale : nil
      end

      def build_page_contents(page)
        contents = []

        if page.respond_to?(:ordered_visible_page_contents)
          contents = page.ordered_visible_page_contents.map do |page_content|
            raw_html = page_content.is_rails_part ? nil : page_content.content&.raw
            localized_html = raw_html.present? ? localize_html_urls(raw_html) : nil

            {
              "page_part_key" => page_content.page_part_key,
              "sort_order" => page_content.sort_order,
              "visible" => page_content.visible_on_page,
              "is_rails_part" => page_content.is_rails_part || false,
              "rendered_html" => localized_html,
              "label" => page_content.label
            }
          end
        end

        # Inject featured listings for home page
        if page.slug == "home"
          contents.concat(build_home_page_features)
        end

        contents
      end

      def build_home_page_features
        [
          build_featured_listing_part("sale"),
          build_featured_listing_part("rental")
        ]
      end

      def build_featured_listing_part(sale_or_rental)
        is_sale = sale_or_rental == "sale"
        label_key = is_sale ? "propertyForSale" : "propertyForRent"
        part_key_suffix = is_sale ? "featured_sales" : "featured_rentals"
        
        {
          "page_part_key" => "summary_listings_part/#{part_key_suffix}",
          "sort_order" => 999, # Ensure it's at the end
          "visible" => true,
          "is_rails_part" => false,
          "rendered_html" => nil,
          "label" => I18n.t(label_key),
          "summ_listings" => fetch_featured_properties(sale_or_rental)
        }
      end

      def fetch_featured_properties(sale_or_rental)
        base_scope = Pwb::Current.website.listed_properties.where(highlighted: true)
        
        args = {
          sale_or_rental: sale_or_rental,
          currency: "usd", # default
          limit: 6 # User sample showed per_page=6
        }

        properties = base_scope.properties_search(**args)
        properties = properties.limit(args[:limit])

        properties.map { |p| serialize_property_summary(p) }
      end

      # Serializers copied from PropertiesController to ensure consistency
      
      def serialize_property_summary(property)
        {
          id: property.id,
          slug: property.slug,
          reference: property.reference,
          title: property.title,
          price_sale_current_cents: property.price_sale_current_cents,
          price_rental_monthly_current_cents: property.price_rental_monthly_current_cents,
          formatted_price: property.formatted_price,
          currency: property.currency,
          count_bedrooms: property.count_bedrooms,
          count_bathrooms: property.count_bathrooms,
          count_garages: property.count_garages,
          highlighted: property.highlighted,
          for_sale: property.for_sale?,
          for_rent: property.for_rent?,
          primary_image_url: property.primary_image_url,
          prop_photos: serialize_prop_photos(property, limit: 3)
        }.compact
      end

      def serialize_prop_photos(property, limit: 3)
        return [] unless property.respond_to?(:prop_photos)

        property.prop_photos.first(limit).filter_map do |photo|
          next unless photo.has_image?

          if photo.external?
            {
              id: photo.id,
              url: photo.external_url,
              alt: photo.respond_to?(:caption) ? photo.caption.presence : nil,
              position: photo.sort_order,
              variants: {}
            }
          elsif photo.image.attached?
            {
              id: photo.id,
              url: photo_url(photo.image),
              alt: photo.respond_to?(:caption) ? photo.caption.presence : nil,
              position: photo.sort_order,
              variants: generate_photo_variants(photo.image)
            }
          end
        end
      end

      def photo_url(image)
        Rails.application.routes.url_helpers.rails_blob_url(
          image,
          host: resolve_asset_host
        )
      rescue StandardError
        nil
      end

      def generate_photo_variants(image)
        return {} unless image.variable?

        {
          thumbnail: variant_url_for(image, resize_to_limit: [150, 100]),
          small: variant_url_for(image, resize_to_limit: [300, 200]),
          medium: variant_url_for(image, resize_to_limit: [600, 400]),
          large: variant_url_for(image, resize_to_limit: [1200, 800])
        }
      rescue StandardError
        {}
      end

      def variant_url_for(image, transformations)
        Rails.application.routes.url_helpers.rails_representation_url(
          image.variant(transformations).processed,
          host: resolve_asset_host
        )
      rescue StandardError
        nil
      end

      def resolve_asset_host
        ENV.fetch('ASSET_HOST') do
          ENV.fetch('APP_HOST') do
            Rails.application.config.action_controller.asset_host ||
              Rails.application.routes.default_url_options[:host] ||
              request.protocol + request.host_with_port
          end
        end
      end

      # Helper methods for website data

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
