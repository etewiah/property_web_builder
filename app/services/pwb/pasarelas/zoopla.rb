# frozen_string_literal: true

module Pwb
  module Pasarelas
    # Pasarela for Zoopla.co.uk property listings.
    # Extracts data from Zoopla's Next.js structure and JSON-LD.
    class Zoopla < Base
      protected

      def extract_data
        json_ld = find_zoopla_json_ld
        og_tags = extract_og_tags
        next_data = extract_zoopla_next_data

        {
          asset_data: extract_asset_data(json_ld, og_tags, next_data),
          listing_data: extract_listing_data(json_ld, og_tags, next_data),
          images: extract_images(next_data, og_tags)
        }
      end

      private

      def find_zoopla_json_ld
        json_ld_items = extract_json_ld
        # Zoopla uses RealEstateListing or Product schema
        json_ld_items.find do |item|
          type = item["@type"].to_s
          type.include?("RealEstateListing") || type.include?("Product") || type.include?("Residence")
        end || json_ld_items.first || {}
      end

      def extract_zoopla_next_data
        next_data = extract_next_data
        return {} unless next_data

        # Zoopla stores listing data in pageProps.listingDetails or similar
        props = next_data.dig("props", "pageProps") || {}
        props["listingDetails"] || props["listing"] || props["property"] || props
      end

      def extract_asset_data(json_ld, og_tags, next_data)
        address = extract_address_data(json_ld, next_data)
        location = next_data["location"] || next_data.dig("address", "location") || {}

        {
          "street_address" => address[:street],
          "city" => address[:city],
          "region" => address[:region],
          "postal_code" => address[:postal_code],
          "country" => "GB",
          "latitude" => extract_coordinate(location, "latitude", "lat"),
          "longitude" => extract_coordinate(location, "longitude", "lng"),
          "count_bedrooms" => extract_bedrooms(json_ld, next_data),
          "count_bathrooms" => extract_bathrooms(json_ld, next_data),
          "constructed_area" => extract_area(next_data),
          "prop_type_key" => map_property_type(next_data["propertyType"] || next_data["property_type"]),
          "reference" => next_data["listingId"]&.to_s || next_data["id"]&.to_s
        }.compact
      end

      def extract_listing_data(json_ld, og_tags, next_data)
        {
          "title" => extract_title(og_tags, next_data),
          "description" => extract_description(json_ld, og_tags, next_data),
          "price_sale_current" => extract_price(json_ld, next_data),
          "currency" => "GBP",
          "visible" => true
        }.compact
      end

      def extract_images(next_data, og_tags)
        images = []

        # From gallery/images array
        gallery = next_data["gallery"] || next_data["images"] || next_data["media"] || []
        gallery.each do |img|
          url = extract_image_url(img)
          images << url if url.present?
        end

        # OG image as fallback
        images << og_tags[:image] if og_tags[:image].present? && images.empty?

        # From HTML if no images found
        if images.empty?
          doc.css('[class*="gallery"] img, [class*="carousel"] img, [data-testid*="image"] img').each do |img|
            src = img["src"] || img["data-src"]
            images << src if valid_zoopla_image?(src)
          end
        end

        images.compact.uniq.first(20)
      end

      def extract_image_url(img)
        if img.is_a?(Hash)
          img["url"] || img["src"] || img["original"] || img.dig("sizes", "large")
        elsif img.is_a?(String)
          img
        end
      end

      def extract_address_data(json_ld, next_data)
        # From JSON-LD
        if json_ld["address"].is_a?(Hash)
          addr = json_ld["address"]
          return {
            street: addr["streetAddress"],
            city: addr["addressLocality"],
            region: addr["addressRegion"],
            postal_code: addr["postalCode"]
          }
        end

        # From Next.js data
        addr = next_data["address"] || {}
        {
          street: addr["displayAddress"] || addr["street"],
          city: addr["townOrCity"] || addr["city"] || addr["locality"],
          region: addr["county"] || addr["region"],
          postal_code: addr["postcode"] || addr["outcode"]
        }
      end

      def extract_coordinate(location, *keys)
        keys.each do |key|
          value = location[key]
          return value.to_f if value
        end
        nil
      end

      def extract_bedrooms(json_ld, next_data)
        json_ld["numberOfBedrooms"]&.to_i ||
          next_data["numBedrooms"]&.to_i ||
          next_data["bedrooms"]&.to_i ||
          extract_from_features(next_data, /bedroom/i)
      end

      def extract_bathrooms(json_ld, next_data)
        json_ld["numberOfBathroomsTotal"]&.to_f ||
          next_data["numBathrooms"]&.to_f ||
          next_data["bathrooms"]&.to_f ||
          extract_from_features(next_data, /bathroom/i)
      end

      def extract_from_features(next_data, pattern)
        features = next_data["features"] || next_data["keyFeatures"] || []
        features.each do |feature|
          text = feature.is_a?(Hash) ? feature["content"] : feature.to_s
          match = text.match(/(\d+)\s*#{pattern.source}/i)
          return match[1].to_i if match
        end
        nil
      end

      def extract_area(next_data)
        # Direct area field
        area = next_data["floorArea"] || next_data["area"]
        if area.is_a?(Hash)
          value = area["value"] || area["sqft"] || area["sqm"]
          unit = area["unit"] || "sqft"
          return convert_area(value, unit)
        elsif area
          return area.to_f
        end

        # From features
        features = next_data["features"] || []
        features.each do |feature|
          text = feature.is_a?(Hash) ? feature["content"] : feature.to_s
          match = text.match(/(\d+(?:,\d+)?)\s*sq\.?\s*(ft|m)/i)
          if match
            value = match[1].delete(",").to_f
            unit = match[2].downcase == "ft" ? "sqft" : "sqm"
            return convert_area(value, unit)
          end
        end

        nil
      end

      def convert_area(value, unit)
        return nil unless value

        if unit.to_s.downcase.include?("ft")
          # Convert sqft to sqm
          (value.to_f * 0.092903).round(2)
        else
          value.to_f
        end
      end

      def extract_title(og_tags, next_data)
        next_data["title"] ||
          next_data.dig("address", "displayAddress") ||
          og_tags[:title]&.split("|")&.first&.strip
      end

      def extract_description(json_ld, og_tags, next_data)
        next_data["description"] ||
          next_data["detailedDescription"] ||
          json_ld["description"] ||
          og_tags[:description]
      end

      def extract_price(json_ld, next_data)
        # From offers in JSON-LD
        price = json_ld.dig("offers", "price")
        return clean_price(price) if price

        # From Next.js data
        price = next_data["price"] || next_data.dig("pricing", "price")
        if price.is_a?(Hash)
          return clean_price(price["value"] || price["amount"])
        elsif price
          return clean_price(price)
        end

        nil
      end

      def map_property_type(type)
        return "other" if type.blank?

        type = type.to_s.downcase
        case type
        when /flat|apartment|maisonette|penthouse/
          "apartment"
        when /detached|semi-detached|terrace|bungalow|cottage|house|villa/
          "house"
        when /studio/
          "studio"
        when /land|plot/
          "land"
        when /commercial|office|retail|industrial/
          "commercial"
        else
          "other"
        end
      end

      def valid_zoopla_image?(url)
        return false if url.blank?
        return false if url.include?("placeholder")
        return false if url.include?("logo")
        return false if url.include?("icon")

        url.match?(/\.(jpe?g|png|webp)/i) || url.include?("lc.zoocdn.com")
      end
    end
  end
end
