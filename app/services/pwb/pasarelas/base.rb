# frozen_string_literal: true

require "nokogiri"
require "json"

module Pwb
  module Pasarelas
    # Base class for pasarelas (data transformers).
    # Pasarelas extract structured property data from raw HTML.
    # Named after the Spanish word for "gateway" - they transform
    # portal-specific data into a standardized format.
    class Base
      attr_reader :scraped_property, :html, :url, :doc

      def initialize(scraped_property)
        @scraped_property = scraped_property
        @html = scraped_property.raw_html
        @url = scraped_property.source_url
        @doc = Nokogiri::HTML(html) if html.present?
      end

      # Main entry point. Extracts data and saves to scraped_property.
      # Returns the extracted data hash.
      def call
        return empty_result unless doc.present?

        extracted = extract_data

        scraped_property.update!(
          extracted_data: {
            "asset_data" => extracted[:asset_data] || {},
            "listing_data" => extracted[:listing_data] || {}
          },
          extracted_images: extracted[:images] || []
        )

        extracted
      rescue StandardError => e
        Rails.logger.error("[Pasarela] Extraction failed: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
        empty_result
      end

      protected

      # Override in subclasses to extract portal-specific data.
      # Should return:
      #   {
      #     asset_data: { ... },    # Property characteristics
      #     listing_data: { ... },  # Listing/sale details
      #     images: [ ... ]         # Array of image URLs
      #   }
      def extract_data
        raise NotImplementedError, "#{self.class} must implement #extract_data"
      end

      # --- Common Extraction Helpers ---

      # Extract JSON-LD structured data (schema.org)
      def extract_json_ld
        scripts = doc.css('script[type="application/ld+json"]')
        scripts.filter_map do |script|
          JSON.parse(script.text.strip)
        rescue JSON::ParserError
          nil
        end
      end

      # Extract Next.js page data (common in modern property sites)
      def extract_next_data
        script = doc.at_css("script#__NEXT_DATA__")
        return nil unless script

        JSON.parse(script.text.strip)
      rescue JSON::ParserError
        nil
      end

      # Extract Open Graph meta tags
      def extract_og_tags
        {
          title: meta_content("og:title"),
          description: meta_content("og:description"),
          image: meta_content("og:image"),
          url: meta_content("og:url"),
          type: meta_content("og:type"),
          site_name: meta_content("og:site_name")
        }.compact
      end

      # Extract Twitter card meta tags
      def extract_twitter_tags
        {
          title: meta_content("twitter:title"),
          description: meta_content("twitter:description"),
          image: meta_content("twitter:image")
        }.compact
      end

      # Get meta tag content by property or name
      def meta_content(name)
        doc.at("meta[property='#{name}']")&.[]("content") ||
          doc.at("meta[name='#{name}']")&.[]("content")
      end

      # Clean price string to number
      def clean_price(price_string)
        return nil if price_string.blank?

        # Remove currency symbols and non-numeric characters except decimal point
        cleaned = price_string.to_s.gsub(/[^\d.,]/, "")
        # Handle European format (1.234,56) vs US format (1,234.56)
        if cleaned.match?(/\d+\.\d{3}[,.]?\d*$/) || cleaned.match?(/^\d{1,3}(\.\d{3})+$/)
          # European format: 1.234.567,89 -> 1234567.89
          cleaned = cleaned.tr(".", "").tr(",", ".")
        else
          # US format: 1,234,567.89 -> 1234567.89
          cleaned = cleaned.delete(",")
        end
        cleaned.to_f
      end

      # Extract all image URLs from common sources
      def extract_all_images
        images = []

        # From img tags
        doc.css("img").each do |img|
          src = img["src"] || img["data-src"] || img["data-lazy-src"]
          images << absolutize_url(src) if valid_image_url?(src)
        end

        # From picture source tags
        doc.css("picture source").each do |source|
          srcset = source["srcset"]
          next unless srcset

          # Take the first URL from srcset
          first_url = srcset.split(",").first&.split(" ")&.first
          images << absolutize_url(first_url) if valid_image_url?(first_url)
        end

        # From CSS background images
        doc.css("[style*='background']").each do |el|
          style = el["style"]
          if style && (match = style.match(/url\(['"]?([^'")\s]+)['"]?\)/))
            url = match[1]
            images << absolutize_url(url) if valid_image_url?(url)
          end
        end

        images.compact.uniq
      end

      # Extract page title
      def page_title
        doc.at("title")&.text&.strip
      end

      # Extract meta description
      def meta_description
        meta_content("description")
      end

      # Get text content from first matching selector
      def text_at(selector)
        doc.at_css(selector)&.text&.strip
      end

      # Get text content from all matching selectors
      def texts_at(selector)
        doc.css(selector).map { |el| el.text.strip }.reject(&:empty?)
      end

      private

      def empty_result
        { asset_data: {}, listing_data: {}, images: [] }
      end

      def valid_image_url?(url)
        return false if url.blank?
        return false if url.start_with?("data:")
        return false if url.include?("placeholder")
        return false if url.include?("spacer")
        return false if url.include?("tracking")
        return false if url.include?("pixel")

        url.match?(/\.(jpe?g|png|webp|gif|avif)/i) || url.include?("/image")
      end

      def absolutize_url(url)
        return nil if url.blank?
        return url if url.start_with?("http")

        begin
          base_uri = URI.parse(@url)
          URI.join("#{base_uri.scheme}://#{base_uri.host}", url).to_s
        rescue URI::InvalidURIError
          nil
        end
      end
    end
  end
end
