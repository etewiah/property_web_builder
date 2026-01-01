# frozen_string_literal: true

module Pwb
  module Pasarelas
    # Pasarela for Idealista.com property listings.
    # Extracts data from Idealista's specific HTML structure for Spain/Portugal/Italy.
    class Idealista < Base
      protected

      def extract_data
        json_ld = find_idealista_json_ld
        og_tags = extract_og_tags

        {
          asset_data: extract_asset_data(json_ld, og_tags),
          listing_data: extract_listing_data(json_ld, og_tags),
          images: extract_images
        }
      end

      private

      def find_idealista_json_ld
        json_ld_items = extract_json_ld
        # Idealista typically uses Product or RealEstateListing schema
        json_ld_items.find do |item|
          type = item["@type"].to_s
          type.include?("Product") || type.include?("RealEstateListing") || type.include?("Residence")
        end || json_ld_items.first || {}
      end

      def extract_asset_data(json_ld, og_tags)
        {
          "street_address" => extract_street_address,
          "city" => extract_city,
          "region" => extract_region,
          "postal_code" => extract_postal_code,
          "country" => detect_country,
          "latitude" => extract_latitude_from_html,
          "longitude" => extract_longitude_from_html,
          "count_bedrooms" => extract_bedrooms_html,
          "count_bathrooms" => extract_bathrooms_html,
          "constructed_area" => extract_area_html,
          "plot_area" => extract_plot_area_html,
          "prop_type_key" => extract_property_type_html,
          "year_construction" => extract_year_construction,
          "energy_rating" => extract_energy_rating,
          "reference" => extract_reference
        }.compact
      end

      def extract_listing_data(json_ld, og_tags)
        {
          "title" => og_tags[:title] || extract_title_html,
          "description" => extract_description_html || og_tags[:description],
          "price_sale_current" => extract_price_html,
          "currency" => "EUR",
          "visible" => true
        }.compact
      end

      def extract_images
        images = []

        # Main gallery images - Idealista uses data-ondemand-img
        doc.css("[data-ondemand-img], .detail-image img, .gallery-image img").each do |img|
          src = img["data-ondemand-img"] || img["src"] || img["data-src"]
          next unless valid_idealista_image?(src)

          # Get full size version
          src = src.gsub(/WEB_LISTING/, "WEB_DETAIL").gsub(/_M\./, "_XL.")
          images << absolutize_idealista_url(src)
        end

        # Fallback to any images in the main content
        if images.empty?
          doc.css(".multimedia img, .photos img, [class*='gallery'] img").each do |img|
            src = img["src"] || img["data-src"]
            images << absolutize_idealista_url(src) if valid_idealista_image?(src)
          end
        end

        images.compact.uniq.first(20)
      end

      # --- HTML Extraction Methods ---

      def extract_title_html
        text_at(".main-info__title-main") ||
          text_at("h1.title") ||
          text_at(".property-title") ||
          page_title&.split("|")&.first&.strip
      end

      def extract_description_html
        text_at(".comment p") ||
          text_at(".adCommentsLanguage") ||
          text_at("[class*='description']")
      end

      def extract_price_html
        price_text = text_at(".info-data-price") ||
                     text_at(".price") ||
                     text_at("[class*='price']")

        clean_price(price_text)
      end

      def extract_street_address
        text_at(".main-info__title-minor") ||
          text_at("[class*='address']")
      end

      def extract_city
        # Idealista shows location in breadcrumbs or specific elements
        breadcrumbs = doc.css(".breadcrumb-navigation a, .breadcrumb a")
        breadcrumbs.each do |crumb|
          text = crumb.text.strip
          # Skip generic terms
          next if text.match?(/venta|alquiler|comprar|sale|rent|home|inicio/i)

          return text if text.present?
        end

        # From URL
        if @url.match?(/idealista\.(com|pt|it)\/inmueble\/(\d+)/)
          # Try to extract from the page content
          location = text_at(".main-info__title-minor")
          return location.split(",").last&.strip if location
        end

        nil
      end

      def extract_region
        breadcrumbs = doc.css(".breadcrumb-navigation a, .breadcrumb a").map { |a| a.text.strip }
        # Usually: Home > Province > City > District
        breadcrumbs[1] if breadcrumbs.length > 2
      end

      def extract_postal_code
        # Idealista often includes postcode in address
        address_text = text_at(".main-info__title-minor") || text_at("[class*='address']")
        return nil unless address_text

        # Spanish postal code pattern (5 digits)
        match = address_text.match(/\b(\d{5})\b/)
        match&.[](1)
      end

      def detect_country
        # Detect from URL domain
        case @url
        when /idealista\.pt/
          "PT"
        when /idealista\.it/
          "IT"
        else
          "ES" # Default to Spain
        end
      end

      def extract_latitude_from_html
        # Idealista embeds coordinates in various places
        doc.css("script").each do |script|
          text = script.text
          if (match = text.match(/"latitude"\s*:\s*([\d.]+)/))
            return match[1].to_f
          end
          if (match = text.match(/lat\s*[:=]\s*([\d.]+)/))
            return match[1].to_f
          end
        end
        nil
      end

      def extract_longitude_from_html
        doc.css("script").each do |script|
          text = script.text
          if (match = text.match(/"longitude"\s*:\s*([\d.-]+)/))
            return match[1].to_f
          end
          if (match = text.match(/lng\s*[:=]\s*([\d.-]+)/))
            return match[1].to_f
          end
        end
        nil
      end

      def extract_bedrooms_html
        # Idealista uses specific info items
        doc.css(".info-features span, .details-property_features li, [class*='feature']").each do |el|
          text = el.text
          match = text.match(/(\d+)\s*(hab|dormitor|bedroom|camera)/i)
          return match[1].to_i if match
        end

        # Fallback to page text
        match = doc.text.match(/(\d+)\s*(habitacion|dormitor|bedroom)/i)
        match ? match[1].to_i : nil
      end

      def extract_bathrooms_html
        doc.css(".info-features span, .details-property_features li, [class*='feature']").each do |el|
          text = el.text
          match = text.match(/(\d+)\s*(ba[ñn]o|bath|bagn)/i)
          return match[1].to_i if match
        end

        match = doc.text.match(/(\d+)\s*(ba[ñn]o|bathroom|bagn)/i)
        match ? match[1].to_i : nil
      end

      def extract_area_html
        # Look for constructed area (m²)
        doc.css(".info-features span, .details-property_features li, [class*='feature']").each do |el|
          text = el.text
          match = text.match(/(\d+(?:\.\d+)?)\s*m[²2]/i)
          return match[1].to_f if match
        end

        # From general text
        match = doc.text.match(/(\d+(?:[\.,]\d+)?)\s*m[²2]\s*(construid|built|util)/i)
        clean_price(match[1]) if match
      end

      def extract_plot_area_html
        # Look for plot/terrain area
        doc.css(".info-features span, .details-property_features li").each do |el|
          text = el.text
          if text.match?(/parcela|terreno|plot|terrain/i)
            match = text.match(/(\d+(?:[\.,]\d+)?)\s*m[²2]/i)
            return clean_price(match[1]) if match
          end
        end
        nil
      end

      def extract_property_type_html
        type_text = text_at(".main-info__title-main") ||
                    text_at(".typology") ||
                    text_at("[class*='property-type']")

        map_spanish_property_type(type_text)
      end

      def map_spanish_property_type(type_text)
        return "other" if type_text.blank?

        type = type_text.downcase
        case type
        when /piso|apartamento|[aá]tico|flat|apartment|appartamento/
          "apartment"
        when /casa|chalet|villa|adosado|pareado|house|unifamiliar/
          "house"
        when /estudio|studio|monolocale/
          "studio"
        when /terreno|parcela|land|plot|solar/
          "land"
        when /local|oficina|commercial|office|negocio/
          "commercial"
        when /garaje|parking|trastero|storage/
          "parking"
        else
          "other"
        end
      end

      def extract_year_construction
        doc.css(".details-property li, .info-features span").each do |el|
          text = el.text
          match = text.match(/construi?d?o?\s*(?:en\s+)?(\d{4})/i)
          return match[1].to_i if match && match[1].to_i > 1800
        end
        nil
      end

      def extract_energy_rating
        doc.css(".energy-certificate, [class*='energy'], [class*='certificate']").each do |el|
          text = el.text.upcase
          match = text.match(/\b([A-G])\b/)
          return match[1] if match
        end
        nil
      end

      def extract_reference
        # Idealista property ID from URL
        match = @url.match(/inmueble\/(\d+)/)
        match&.[](1)
      end

      def valid_idealista_image?(url)
        return false if url.blank?
        return false if url.include?("logo")
        return false if url.include?("icon")
        return false if url.include?("placeholder")

        url.match?(/\.(jpe?g|png|webp)/i) || url.include?("img3.idealista")
      end

      def absolutize_idealista_url(url)
        return nil if url.blank?
        return url if url.start_with?("http")

        if url.start_with?("//")
          "https:#{url}"
        else
          "https://img3.idealista.com#{url}"
        end
      end
    end
  end
end
