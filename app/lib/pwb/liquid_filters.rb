# frozen_string_literal: true

module Pwb
  # Custom Liquid filters for PropertyWebBuilder templates
  #
  # Usage in Liquid templates:
  #   {{ "/search/buy" | localize_url }}
  #   {{ page_part.cta_link.content | localize_url }}
  #
  module LiquidFilters
    # Prepend the current locale to a URL path
    #
    # @param url [String] The URL path (e.g., "/search/buy", "/contact")
    # @return [String] The localized URL (e.g., "/es/search/buy", "/es/contact")
    #
    # Examples:
    #   {{ "/search/buy" | localize_url }}  => "/es/search/buy" (when locale is :es)
    #   {{ "/contact" | localize_url }}     => "/fr/contact" (when locale is :fr)
    #   {{ "https://example.com" | localize_url }} => "https://example.com" (external URLs unchanged)
    #   {{ "" | localize_url }}             => "" (empty strings unchanged)
    #   {{ "#section" | localize_url }}     => "#section" (anchors unchanged)
    #
    def localize_url(url)
      return url if url.blank?
      return url if external_url?(url)
      return url if anchor_only?(url)
      return url if already_localized?(url)

      locale = current_locale
      return url if locale.blank? || locale.to_s == I18n.default_locale.to_s

      # Ensure URL starts with /
      path = url.start_with?('/') ? url : "/#{url}"

      "/#{locale}#{path}"
    end

    private

    # Check if URL is external (starts with http://, https://, or //)
    def external_url?(url)
      url.match?(%r{\A(https?:)?//})
    end

    # Check if URL is an anchor-only link
    def anchor_only?(url)
      url.start_with?('#')
    end

    # Check if URL already has a locale prefix
    def already_localized?(url)
      available_locales = I18n.available_locales.map(&:to_s)
      # Match /en/, /es/, /fr/, etc. at the start of the path
      url.match?(%r{\A/(#{available_locales.join('|')})(/|$)})
    end

    # Get current locale from context or I18n
    def current_locale
      # Try to get locale from Liquid context registers
      if @context&.registers&.dig(:locale)
        @context.registers[:locale]
      else
        I18n.locale
      end
    end
  end
end
