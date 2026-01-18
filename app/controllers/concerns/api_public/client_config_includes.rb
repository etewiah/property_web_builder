# frozen_string_literal: true

module ApiPublic
  # Concern for aggregating optional data blocks in /client-config endpoint
  # Enables frontend to fetch multiple data types in a single request
  module ClientConfigIncludes
    extend ActiveSupport::Concern

    private

    # Parse include parameter and build additional data blocks
    # @param includes [String] Comma-separated list of data blocks to include
    # @return [Hash] Hash with included data and any errors
    def build_included_data(includes)
      return { data: {}, errors: [] } if includes.blank?

      requested = includes.split(',').map(&:strip).map(&:to_sym)
      data = {}
      errors = []

      include_methods = {
        site_details: :build_site_details,
        links: :build_links,
        translations: :build_translations,
        homepage: :build_homepage,
        testimonials: :build_testimonials,
        featured_properties: :build_featured_properties
      }

      requested.each do |block|
        next unless include_methods.key?(block)

        begin
          data[block] = send(include_methods[block])
        rescue StandardError => e
          errors << { section: block.to_s, message: e.message }
          Rails.logger.error("[ClientConfig] Error building #{block}: #{e.message}")
        end
      end

      { data: data, errors: errors }
    end

    # Build site_details block (mirrors SiteDetailsController#index)
    def build_site_details
      website = @current_website
      return nil unless website

      website.as_json.merge(
        analytics: build_analytics_config(website)
      )
    end

    # Build analytics config for site_details
    def build_analytics_config(website)
      config = {}

      if website.respond_to?(:posthog_api_key) && website.posthog_api_key.present?
        config[:posthog_key] = website.posthog_api_key
        config[:posthog_host] = website.respond_to?(:posthog_host) ? website.posthog_host : "https://app.posthog.com"
      end

      config[:ga4_id] = website.ga4_measurement_id if website.respond_to?(:ga4_measurement_id) && website.ga4_measurement_id.present?
      config[:gtm_id] = website.gtm_container_id if website.respond_to?(:gtm_container_id) && website.gtm_container_id.present?

      config.presence
    end

    # Build links block - returns all links with position/placement
    def build_links
      return [] unless @current_website

      @current_website.links
        .where(visible: true)
        .order('sort_order asc')
        .map(&:as_api_json)
    end

    # Build translations block for requested locale
    def build_translations
      locale = params[:locale] || I18n.default_locale
      I18n.t(".", locale: locale)
    end

    # Build homepage block with rendered content
    def build_homepage
      return nil unless @current_website

      page = @current_website.pages.find_by_slug('home')
      return nil unless page

      {
        id: page.id,
        slug: page.slug,
        title: page.title,
        meta_description: page.try(:meta_description),
        page_contents: build_page_contents(page)
      }
    end

    # Build rendered page contents for homepage
    def build_page_contents(page)
      return [] unless page.respond_to?(:ordered_visible_page_contents)

      page.ordered_visible_page_contents.map do |page_content|
        raw_html = page_content.is_rails_part ? nil : page_content.content&.raw

        {
          page_part_key: page_content.page_part_key,
          sort_order: page_content.sort_order,
          visible: page_content.visible_on_page,
          is_rails_part: page_content.is_rails_part || false,
          rendered_html: raw_html,
          label: page_content.label
        }
      end
    end

    # Build testimonials block
    def build_testimonials
      return [] unless @current_website

      limit = (params[:testimonials_limit] || 6).to_i
      @current_website.testimonials
        .visible
        .ordered
        .limit(limit)
        .map(&:as_api_json)
    end

    # Build featured_properties block - grouped by sale/rental
    def build_featured_properties
      return { sale: [], rental: [] } unless @current_website

      per_group = (params[:properties_per_group] || 3).to_i
      base_scope = @current_website.listed_properties.where(highlighted: true)

      # Common search args
      common_args = {
        currency: "usd",
        for_sale_price_from: "none",
        for_sale_price_till: "none",
        for_rent_price_from: "none",
        for_rent_price_till: "none",
        bedrooms_from: "none",
        bathrooms_from: "none",
        property_type: "none"
      }

      # Fetch sale properties
      sale_scope = base_scope.properties_search(**common_args.merge(sale_or_rental: "sale"))
      sale_properties = sale_scope.limit(per_group)

      # Fetch rental properties
      rental_scope = base_scope.properties_search(**common_args.merge(sale_or_rental: "rental"))
      rental_properties = rental_scope.limit(per_group)

      {
        sale: sale_properties.map { |p| property_summary(p) },
        rental: rental_properties.map { |p| property_summary(p) }
      }
    end

    # Summary representation of a property for includes
    def property_summary(property)
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
        highlighted: property.highlighted,
        for_sale: property.for_sale?,
        for_rent: property.for_rent?,
        primary_image_url: property.primary_image_url
      }.compact
    end
  end
end
