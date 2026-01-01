# frozen_string_literal: true

module Pwb
  module Pasarelas
    # Generic pasarela for unknown property portals.
    # Uses common patterns (JSON-LD, Open Graph, common CSS selectors)
    # to extract property data from any website.
    class Generic < Base
      # Common CSS selectors for property data across various sites
      PRICE_SELECTORS = [
        ".price", "[class*='price']", "[id*='price']",
        ".listing-price", ".property-price", ".asking-price",
        "[data-price]", ".amount", ".cost"
      ].freeze

      BEDROOM_SELECTORS = [
        "[class*='bedroom']", "[class*='bed']", "[data-beds]",
        ".beds", ".bedrooms", "[aria-label*='bedroom']"
      ].freeze

      BATHROOM_SELECTORS = [
        "[class*='bathroom']", "[class*='bath']", "[data-baths]",
        ".baths", ".bathrooms", "[aria-label*='bathroom']"
      ].freeze

      ADDRESS_SELECTORS = [
        ".address", "[class*='address']", "[class*='location']",
        ".property-address", ".listing-address", "[itemprop='address']"
      ].freeze

      DESCRIPTION_SELECTORS = [
        ".description", "[class*='description']", ".property-description",
        ".listing-description", "[itemprop='description']", ".about"
      ].freeze

      GALLERY_SELECTORS = [
        "[class*='gallery'] img", "[class*='slider'] img",
        "[class*='carousel'] img", "[class*='photo'] img",
        ".property-images img", ".listing-images img",
        "[class*='lightbox'] img", "figure img"
      ].freeze

      protected

      def extract_data
        og_tags = extract_og_tags
        json_ld = find_property_json_ld
        next_data = extract_property_from_next_data

        {
          asset_data: extract_asset_data(og_tags, json_ld, next_data),
          listing_data: extract_listing_data(og_tags, json_ld, next_data),
          images: extract_property_images(og_tags)
        }
      end

      private

      def find_property_json_ld
        json_ld_items = extract_json_ld

        # Look for RealEstateListing, Product, or Place schema
        json_ld_items.find do |item|
          type = item["@type"].to_s.downcase
          %w[realestatelisting product residence house apartment place].any? { |t| type.include?(t) }
        end || json_ld_items.first || {}
      end

      def extract_property_from_next_data
        next_data = extract_next_data
        return {} unless next_data

        # Common Next.js patterns for property data
        props = next_data.dig("props", "pageProps") || {}
        props["property"] || props["listing"] || props["data"] || props
      end

      def extract_asset_data(og_tags, json_ld, next_data)
        address_data = extract_address(json_ld, next_data)

        {
          "title" => extract_title(og_tags, json_ld, next_data),
          "description" => extract_description(og_tags, json_ld, next_data),
          "street_address" => address_data[:street],
          "city" => address_data[:city],
          "region" => address_data[:region],
          "postal_code" => address_data[:postal_code],
          "country" => address_data[:country],
          "latitude" => extract_latitude(json_ld, next_data),
          "longitude" => extract_longitude(json_ld, next_data),
          "count_bedrooms" => extract_bedrooms(json_ld, next_data),
          "count_bathrooms" => extract_bathrooms(json_ld, next_data),
          "constructed_area" => extract_area(json_ld, next_data),
          "prop_type_key" => extract_property_type(json_ld, next_data),
          "reference" => extract_reference(next_data)
        }.compact
      end

      def extract_listing_data(og_tags, json_ld, next_data)
        price_data = extract_price(json_ld, next_data)
        listing_type = detect_listing_type_from_data(json_ld, next_data)

        result = {
          "title" => extract_title(og_tags, json_ld, next_data),
          "description" => extract_description(og_tags, json_ld, next_data),
          "currency" => price_data[:currency] || "EUR",
          "visible" => true,
          "listing_type" => listing_type
        }

        # Add appropriate price field based on listing type
        if listing_type == "rental"
          result["price_rental_monthly"] = price_data[:price]
        else
          result["price_sale_current"] = price_data[:price]
        end

        result.compact
      end

      def detect_listing_type_from_data(json_ld, next_data)
        # Check JSON-LD for type hints
        if json_ld["@type"].to_s.downcase.include?("rental")
          return "rental"
        end

        # Check Next.js data
        listing_type = next_data["listingType"] || next_data["listing_type"] || next_data["type"]
        if listing_type.to_s.downcase.match?(/rent|alquiler|location|affitto/)
          return "rental"
        end

        # Check page text for rental indicators
        page_text = doc.text.downcase
        rental_indicators = page_text.scan(/\b(per month|pcm|pw|per week|rent|to let|alquiler|mensual|affitto)\b/).flatten
        sale_indicators = page_text.scan(/\b(for sale|asking price|offers over|venta|verkauf)\b/).flatten

        if rental_indicators.length > sale_indicators.length * 2
          "rental"
        else
          "sale"
        end
      end

      # --- Field Extraction Methods ---

      def extract_title(og_tags, json_ld, next_data)
        og_tags[:title] ||
          json_ld["name"] ||
          next_data["title"] ||
          page_title&.split(/[|\-–]/)&.first&.strip
      end

      def extract_description(og_tags, json_ld, next_data)
        og_tags[:description] ||
          json_ld["description"] ||
          next_data["description"] ||
          extract_description_from_html ||
          meta_description
      end

      def extract_description_from_html
        DESCRIPTION_SELECTORS.each do |selector|
          text = text_at(selector)
          return text if text.present? && text.length > 50
        end
        nil
      end

      def extract_address(json_ld, next_data)
        # Try JSON-LD address first
        if json_ld["address"].is_a?(Hash)
          addr = json_ld["address"]
          return {
            street: addr["streetAddress"],
            city: addr["addressLocality"],
            region: addr["addressRegion"],
            postal_code: addr["postalCode"],
            country: addr["addressCountry"]
          }
        end

        # Try Next.js data
        if next_data["address"].is_a?(Hash)
          addr = next_data["address"]
          return {
            street: addr["street"] || addr["streetAddress"],
            city: addr["city"] || addr["locality"],
            region: addr["region"] || addr["state"],
            postal_code: addr["postcode"] || addr["postalCode"],
            country: addr["country"]
          }
        end

        # Try HTML selectors
        address_text = nil
        ADDRESS_SELECTORS.each do |selector|
          text = text_at(selector)
          if text.present?
            address_text = text
            break
          end
        end

        parse_address_string(address_text)
      end

      def parse_address_string(address_text)
        return {} if address_text.blank?

        # Simple heuristic: split by comma, last part might be postcode/city
        parts = address_text.split(",").map(&:strip)

        {
          street: parts.first,
          city: parts.length > 1 ? parts[-1] : nil,
          region: nil,
          postal_code: extract_postcode_from_text(address_text),
          country: nil
        }
      end

      def extract_postcode_from_text(text)
        return nil if text.blank?

        # UK postcode pattern
        uk_match = text.match(/[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}/i)
        return uk_match[0].upcase if uk_match

        # US ZIP code
        us_match = text.match(/\b\d{5}(-\d{4})?\b/)
        return us_match[0] if us_match

        # European postal codes (4-5 digits)
        eu_match = text.match(/\b\d{4,5}\b/)
        eu_match&.[](0)
      end

      def extract_latitude(json_ld, next_data)
        json_ld.dig("geo", "latitude") ||
          next_data["latitude"] ||
          next_data.dig("location", "lat") ||
          next_data.dig("coordinates", "lat")
      end

      def extract_longitude(json_ld, next_data)
        json_ld.dig("geo", "longitude") ||
          next_data["longitude"] ||
          next_data.dig("location", "lng") ||
          next_data.dig("coordinates", "lng")
      end

      def extract_bedrooms(json_ld, next_data)
        # From structured data
        beds = json_ld["numberOfBedrooms"] || next_data["bedrooms"] || next_data["beds"]
        return beds.to_i if beds

        # From HTML
        BEDROOM_SELECTORS.each do |selector|
          doc.css(selector).each do |el|
            text = el.text
            match = text.match(/(\d+)\s*(bed|bedroom|br|hab)/i)
            return match[1].to_i if match
          end
        end

        # From page text
        match = doc.text.match(/(\d+)\s*(bed|bedroom|dormitor)/i)
        match ? match[1].to_i : nil
      end

      def extract_bathrooms(json_ld, next_data)
        # From structured data
        baths = json_ld["numberOfBathroomsTotal"] ||
          json_ld["numberOfBathrooms"] ||
          next_data["bathrooms"] ||
          next_data["baths"]
        return baths.to_f if baths

        # From HTML
        BATHROOM_SELECTORS.each do |selector|
          doc.css(selector).each do |el|
            text = el.text
            match = text.match(/(\d+(?:\.\d+)?)\s*(bath|bathroom|ba[ñn]o)/i)
            return match[1].to_f if match
          end
        end

        # From page text
        match = doc.text.match(/(\d+(?:\.\d+)?)\s*(bath|bathroom|ba[ñn]o)/i)
        match ? match[1].to_f : nil
      end

      def extract_area(json_ld, next_data)
        # From structured data
        area = json_ld["floorSize"]
        if area.is_a?(Hash)
          return area["value"].to_f if area["value"]
        elsif area
          return clean_price(area.to_s)
        end

        area = next_data["area"] || next_data["sqft"] || next_data["size"]
        return clean_price(area.to_s) if area

        # From HTML - look for sqm, sqft, m2 patterns
        match = doc.text.match(/(\d+(?:[.,]\d+)?)\s*(sq\.?\s*(?:m|ft|meters?|feet)|m[²2])/i)
        clean_price(match[1]) if match
      end

      def extract_property_type(json_ld, next_data)
        type = json_ld["@type"] || next_data["propertyType"] || next_data["type"]
        return nil if type.blank?

        type = type.to_s.downcase
        case type
        when /apartment|flat|piso|apartamento/
          "apartment"
        when /house|casa|chalet|villa|detached|semi/
          "house"
        when /studio|estudio/
          "studio"
        when /land|terreno|plot/
          "land"
        when /commercial|local|office|oficina/
          "commercial"
        else
          "other"
        end
      end

      def extract_reference(next_data)
        next_data["id"] || next_data["reference"] || next_data["propertyId"]
      end

      def extract_price(json_ld, next_data)
        # From JSON-LD offers
        if json_ld["offers"].is_a?(Hash)
          return {
            price: clean_price(json_ld.dig("offers", "price")),
            currency: json_ld.dig("offers", "priceCurrency")
          }
        end

        # From Next.js data
        price = next_data["price"] || next_data.dig("prices", "price")
        if price
          return {
            price: clean_price(price),
            currency: next_data["currency"] || next_data.dig("prices", "currency")
          }
        end

        # From HTML
        extract_price_from_html
      end

      def extract_price_from_html
        PRICE_SELECTORS.each do |selector|
          doc.css(selector).each do |el|
            text = el.text
            price = clean_price(text)
            next unless price && price > 1000

            # Try to detect currency
            currency = detect_currency(text)
            return { price: price, currency: currency }
          end
        end

        { price: nil, currency: nil }
      end

      def detect_currency(text)
        case text
        when /[£]/
          "GBP"
        when /[$]/
          "USD"
        when /[€]/
          "EUR"
        else
          "EUR" # Default
        end
      end

      def extract_property_images(og_tags)
        images = []

        # OG image first (usually the main property image)
        images << og_tags[:image] if og_tags[:image].present?

        # Gallery images from common selectors
        GALLERY_SELECTORS.each do |selector|
          doc.css(selector).each do |img|
            src = img["src"] || img["data-src"] || img["data-lazy"]
            next unless valid_property_image?(src)

            images << absolutize_url(src)
          end
        end

        # Fallback to all images if no gallery found
        if images.size <= 1
          extract_all_images.each do |img|
            images << img if valid_property_image?(img)
          end
        end

        images.compact.uniq.first(20)
      end

      def valid_property_image?(url)
        return false if url.blank?
        return false if url.start_with?("data:")
        return false if url.length < 20

        # Skip common non-property images
        skip_patterns = %w[
          logo icon avatar placeholder spacer tracking pixel
          button arrow social share facebook twitter linkedin
          google map marker pin loading spinner
        ]

        !skip_patterns.any? { |pattern| url.downcase.include?(pattern) }
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
