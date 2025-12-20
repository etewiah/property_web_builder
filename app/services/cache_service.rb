# frozen_string_literal: true

# CacheService provides centralized caching for commonly accessed data
#
# This service wraps expensive operations with caching to reduce database
# queries and improve response times.
#
# Usage:
#   CacheService.field_keys_for("property-types", website_id)
#   CacheService.website_config(website_id)
#
class CacheService
  class << self
    # Cache field keys by tag for a website
    # Used in search forms and property editing
    def field_keys_for(tag, website_id)
      cache_key = "field_keys/#{website_id}/#{tag}/#{I18n.locale}"

      Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
        FieldKey.get_options_by_tag(tag)
      end
    end

    # Cache website configuration
    # Frequently accessed for theming and settings
    def website_config(website_id)
      cache_key = "website_config/#{website_id}"

      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        website = Pwb::Website.find_by(id: website_id)
        next nil unless website

        {
          theme_name: website.theme_name,
          company_name: website.company_display_name,
          default_locale: website.default_client_locale,
          default_currency: website.default_currency,
          supported_locales: website.supported_locales,
          logo_url: website.logo_url,
          style_variables: website.style_variables
        }
      end
    end

    # Cache property counts for a website
    # Used in dashboards and statistics
    def property_counts(website_id)
      cache_key = "property_counts/#{website_id}"

      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        props = Pwb::ListedProperty.where(website_id: website_id)

        {
          total: props.count,
          for_sale: props.for_sale.count,
          for_rent: props.for_rent.count,
          visible: props.visible.count,
          highlighted: props.where(highlighted: true).count
        }
      end
    end

    # Cache search facets
    # Counts for filters in search forms
    def search_facets(website_id, operation_type)
      cache_key = "search_facets/#{website_id}/#{operation_type}/#{I18n.locale}"

      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        website = Pwb::Website.find_by(id: website_id)
        next {} unless website

        base_scope = if operation_type == "for_rent"
                       website.listed_properties.visible.for_rent
                     else
                       website.listed_properties.visible.for_sale
                     end

        SearchFacetsService.calculate(
          scope: base_scope,
          website: website,
          operation_type: operation_type
        )
      end
    end

    # Cache navigation links for a website
    def navigation_links(website_id)
      cache_key = "nav_links/#{website_id}/#{I18n.locale}"

      Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
        website = Pwb::Website.find_by(id: website_id)
        next [] unless website

        website.pages.visible.where(show_in_top_nav: true)
               .order(:sort_order_top_nav)
               .pluck(:slug, :translations)
               .map do |slug, translations|
          title = translations.dig(I18n.locale.to_s, "page_title") ||
                  translations.dig("en", "page_title") ||
                  slug.titleize
          { slug: slug, title: title }
        end
      end
    end

    # Cache footer links for a website
    def footer_links(website_id)
      cache_key = "footer_links/#{website_id}/#{I18n.locale}"

      Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
        website = Pwb::Website.find_by(id: website_id)
        next [] unless website

        website.pages.visible.where(show_in_footer: true)
               .order(:sort_order_footer)
               .pluck(:slug, :translations)
               .map do |slug, translations|
          title = translations.dig(I18n.locale.to_s, "page_title") ||
                  translations.dig("en", "page_title") ||
                  slug.titleize
          { slug: slug, title: title }
        end
      end
    end

    # Invalidate caches for a website
    def invalidate_website_caches(website_id)
      patterns = [
        "website_config/#{website_id}",
        "property_counts/#{website_id}",
        "nav_links/#{website_id}/*",
        "footer_links/#{website_id}/*",
        "search_facets/#{website_id}/*",
        "field_keys/#{website_id}/*"
      ]

      patterns.each do |pattern|
        if pattern.include?("*")
          # For patterns, we need to delete matching keys
          # This is Redis-specific; memory store doesn't support patterns
          Rails.cache.delete_matched(pattern) rescue nil
        else
          Rails.cache.delete(pattern)
        end
      end
    end

    # Invalidate property-related caches
    def invalidate_property_caches(website_id)
      Rails.cache.delete("property_counts/#{website_id}")
      Rails.cache.delete_matched("search_facets/#{website_id}/*") rescue nil
    end
  end
end
