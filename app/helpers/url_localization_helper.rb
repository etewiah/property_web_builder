# frozen_string_literal: true

# UrlLocalizationHelper
#
# Provides URL localization for both ERB views and HTML content.
# This module handles the core logic of adding locale prefixes to URLs.
#
# For Liquid templates, see Pwb::LiquidFilters which wraps this functionality.
# For HTML content (stored in database), use localize_html_urls to process
# anchor href attributes at render time.
#
# @example In ERB views
#   localized_url("/search/buy")  # => "/es/search/buy" (when locale is :es)
#
# @example Processing HTML content
#   localize_html_urls('<a href="/search/buy">Find</a>')
#   # => '<a href="/es/search/buy">Find</a>' (when locale is :es)
#
module UrlLocalizationHelper
  # Localize a single URL path by prepending the current locale
  #
  # @param url [String] The URL path (e.g., "/search/buy", "/contact")
  # @return [String] The localized URL (e.g., "/es/search/buy")
  #
  # @example
  #   localized_url("/search/buy")  # => "/es/search/buy" (when I18n.locale is :es)
  #   localized_url("/contact")     # => "/fr/contact" (when I18n.locale is :fr)
  #   localized_url("https://example.com")  # => "https://example.com" (external unchanged)
  #
  def localized_url(url)
    return url if url.blank?
    return url if external_url?(url)
    return url if anchor_only?(url)
    return url if already_localized?(url)

    locale = I18n.locale
    return url if locale.blank? || locale.to_s == I18n.default_locale.to_s

    # Ensure URL starts with /
    path = url.start_with?('/') ? url : "/#{url}"

    "/#{locale}#{path}"
  end

  # Process HTML content and localize all internal href URLs
  #
  # This method parses HTML content and updates href attributes on anchor tags
  # to include the current locale prefix. External URLs, anchors, and already
  # localized URLs are left unchanged.
  #
  # @param html_content [String] Raw HTML content
  # @return [String] HTML content with localized URLs
  #
  # @example
  #   localize_html_urls('<a href="/search/buy">Search</a>')
  #   # => '<a href="/es/search/buy">Search</a>'
  #
  #   localize_html_urls('<a href="https://external.com">Link</a>')
  #   # => '<a href="https://external.com">Link</a>' (unchanged)
  #
  def localize_html_urls(html_content)
    return html_content if html_content.blank?

    locale = I18n.locale
    return html_content if locale.blank? || locale.to_s == I18n.default_locale.to_s

    # Use regex to find and replace href attributes
    # This is more reliable than using Nokogiri for partial HTML fragments
    html_content.gsub(/href=["']([^"']+)["']/) do |match|
      url = ::Regexp.last_match(1)
      localized = localized_url(url)
      if localized != url
        "href=\"#{localized}\""
      else
        match
      end
    end
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
end
