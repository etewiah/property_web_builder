# frozen_string_literal: true

module Pwb
  module Pasarelas
    # Pasarela for Rightmove.co.uk property listings.
    # Extracts data from Rightmove's specific HTML structure and JSON-LD.
    class Rightmove < Base
      protected

      def extract_data
        json_ld = find_rightmove_json_ld
        og_tags = extract_og_tags
        page_model = extract_page_model

        {
          asset_data: extract_asset_data(json_ld, og_tags, page_model),
          listing_data: extract_listing_data(json_ld, og_tags, page_model),
          images: extract_images(page_model)
        }
      end

      private

      def find_rightmove_json_ld
        json_ld_items = extract_json_ld
        # Rightmove uses RealEstateListing schema
        json_ld_items.find { |item| item["@type"]&.include?("RealEstateListing") } ||
          json_ld_items.first ||
          {}
      end

      # Rightmove embeds property data in window.PAGE_MODEL
      def extract_page_model
        doc.css("script").each do |script|
          text = script.text
          if text.include?("window.PAGE_MODEL")
            # Extract JSON from: window.PAGE_MODEL = {...}
            match = text.match(/window\.PAGE_MODEL\s*=\s*(\{.+?\});?\s*(?:window\.|$)/m)
            if match
              return JSON.parse(match[1])
            end
          end
        end
        {}
      rescue JSON::ParserError
        {}
      end

      def extract_asset_data(json_ld, og_tags, page_model)
        property = page_model.dig("propertyData") || {}
        address = property["address"] || {}
        location = property["location"] || {}

        {
          "street_address" => address["displayAddress"],
          "city" => address["locality"],
          "region" => address["county"],
          "postal_code" => extract_postcode(address, property),
          "country" => "GB",
          "latitude" => location["latitude"]&.to_f,
          "longitude" => location["longitude"]&.to_f,
          "count_bedrooms" => property["bedrooms"]&.to_i || extract_from_json_ld(json_ld, "numberOfBedrooms"),
          "count_bathrooms" => property["bathrooms"]&.to_i || extract_from_json_ld(json_ld, "numberOfBathroomsTotal"),
          "constructed_area" => extract_area(property),
          "prop_type_key" => map_property_type(property["propertySubType"] || property["propertyType"]),
          "reference" => property["id"]&.to_s
        }.compact
      end

      def extract_listing_data(json_ld, og_tags, page_model)
        property = page_model.dig("propertyData") || {}
        prices = property["prices"] || {}

        {
          "title" => og_tags[:title] || property["text"]&.dig("pageTitle"),
          "description" => extract_description(property, og_tags),
          "price_sale_current" => extract_price(prices, property),
          "currency" => "GBP",
          "visible" => true
        }.compact
      end

      def extract_images(page_model)
        images = []
        property = page_model.dig("propertyData") || {}

        # Main images array
        (property["images"] || []).each do |img|
          url = img["url"] || img["srcUrl"]
          # Rightmove uses templated URLs, get the largest size
          if url
            url = url.gsub(/{size}/, "max").gsub(/\/_max_/, "/_max_")
            images << url
          end
        end

        # Floorplan images
        (property["floorplans"] || []).each do |fp|
          images << fp["url"] if fp["url"]
        end

        images.compact.uniq.first(20)
      end

      def extract_postcode(address, property)
        # Rightmove often has outcode (first part) but not full postcode
        outcode = address["outcode"]
        incode = address["incode"]

        if outcode && incode
          "#{outcode} #{incode}"
        elsif outcode
          outcode
        else
          # Try to extract from display address
          extract_postcode_from_text(address["displayAddress"])
        end
      end

      def extract_area(property)
        # Rightmove provides area in different formats
        sizes = property["sizings"] || []
        sizes.each do |size|
          if size["unit"] == "sqft"
            # Convert sqft to sqm
            return (size["minimumSize"].to_f * 0.092903).round(2)
          elsif size["unit"] == "sqm"
            return size["minimumSize"].to_f
          end
        end
        nil
      end

      def extract_price(prices, property)
        # Primary price
        price = prices["primaryPrice"]
        return clean_price(price) if price

        # From price qualifier
        price = property["price"]&.dig("amount")
        return price.to_f if price

        nil
      end

      def extract_description(property, og_tags)
        # Full description from property data
        text_data = property["text"] || {}
        description = text_data["description"]
        return description if description.present?

        # Fallback to OG description
        og_tags[:description]
      end

      def map_property_type(type)
        return "other" if type.blank?

        type = type.to_s.downcase
        case type
        when /flat|apartment|maisonette/
          "apartment"
        when /detached|semi-detached|terraced|bungalow|cottage|villa|house/
          "house"
        when /studio/
          "studio"
        when /land|plot/
          "land"
        when /commercial|retail|office|industrial/
          "commercial"
        else
          "other"
        end
      end

      def extract_from_json_ld(json_ld, key)
        value = json_ld[key]
        value.to_i if value
      end
    end
  end
end
