# frozen_string_literal: true

require "addressable/uri"
require "open-uri"
require "json"

module Pwb
  module ExternalFeed
    module Providers
      # Provider for Resales Online API (Spanish property market, Costa del Sol).
      # Supports both sales and long-term rental listings.
      class ResalesOnline < BaseProvider
        # API Endpoints
        SEARCH_URL_V6 = "https://webapi.resales-online.com/WebApi/V6/SearchProperties.php"
        SEARCH_URL_V5 = "https://webapi.resales-online.com/WebApi/V5-2/SearchProperties.php"
        DETAILS_URL = "https://webapi.resales-online.com/WebApi/V6/PropertyDetails.php"

        # Language codes
        LANG_CODES = {
          en: "1", es: "2", de: "3", fr: "4", nl: "5",
          da: "6", ru: "7", sv: "8", pl: "9", no: "10", tr: "11"
        }.freeze

        # Sort options
        SORT_OPTIONS = {
          price_asc: "0",
          price_desc: "1",
          location: "2",
          newest: "3",
          oldest: "4",
          listed_newest: "5",
          listed_oldest: "6",
          updated: "3" # Alias for newest
        }.freeze

        def self.provider_name
          :resales_online
        end

        def self.display_name
          "Resales Online"
        end

        def search(params)
          listing_type = params[:listing_type] || :sale
          url = listing_type == :rental ? SEARCH_URL_V5 : SEARCH_URL_V6
          api_id = api_id_for(listing_type)

          query_params = build_search_query(params, api_id)
          full_url = "#{url}?#{query_params}"

          log(:debug, "Search URL: #{full_url}")

          response = fetch_json(full_url)
          normalize_search_results(response, params)
        end

        def find(reference, params = {})
          listing_type = params[:listing_type] || :sale
          api_id = api_id_for(listing_type)
          lang_code = lang_code_for(params[:locale])

          query = URI.encode_www_form({
            p1: p1_constant,
            p2: api_key,
            P_Lang: lang_code,
            p_agency_filterid: agency_filter_id(api_id),
            p_apiid: api_id,
            P_RefId: reference
          })

          full_url = "#{DETAILS_URL}?#{query}"
          log(:debug, "Details URL: #{full_url}")

          response = fetch_json(full_url)

          return nil unless response.dig("Property")

          # Check status
          status = response.dig("Property", "Status", "system")
          property = normalize_property(response["Property"], params)

          if %w[Off\ Market Sold].include?(status)
            property.status = status == "Sold" ? :sold : :unavailable
          end

          property
        end

        def similar(property, params = {})
          limit = params[:limit] || 8

          search_params = {
            locale: params[:locale] || :en,
            listing_type: property.listing_type,
            property_types: [property.property_type_raw].compact,
            location: property.city,
            min_price: ((property.price || 0) * 0.7 / 100).to_i, # Convert from cents
            max_price: ((property.price || 0) * 1.3 / 100).to_i,
            min_bedrooms: property.bedrooms,
            sort: :newest,
            per_page: limit + 1 # +1 to account for excluding current
          }

          result = search(search_params)
          result.properties
                .reject { |p| p.reference == property.reference }
                .first(limit)
        end

        def locations(params = {})
          # Resales Online doesn't have a locations endpoint
          # Return configured locations or defaults
          config[:locations] || default_locations
        end

        def property_types(params = {})
          # Return configured property types or defaults
          config[:property_types] || default_property_types
        end

        def available?
          # Quick test query
          query = URI.encode_www_form({
            p1: p1_constant,
            p2: api_key,
            p_apiid: config[:api_id_sales],
            p_PageSize: "1"
          })

          response = fetch_json("#{SEARCH_URL_V6}?#{query}")
          response.dig("transaction", "status") == "success"
        rescue StandardError => e
          log(:warn, "Availability check failed: #{e.message}")
          false
        end

        protected

        def required_config_keys
          [:api_key, :api_id_sales]
        end

        private

        # --- Configuration Helpers ---

        def api_key
          config[:api_key]
        end

        def p1_constant
          config[:p1_constant] || "1014359"
        end

        def api_id_for(listing_type)
          if listing_type == :rental
            config[:api_id_rentals] || config[:api_id_sales]
          else
            config[:api_id_sales]
          end
        end

        def agency_filter_id(api_id)
          # Certain API IDs require different filter settings
          api_id == "4069" ? "1" : "2"
        end

        def lang_code_for(locale)
          LANG_CODES[locale&.to_sym] || LANG_CODES[:en]
        end

        def default_country
          config[:default_country] || "Spain"
        end

        def image_count
          config[:image_count] || 0 # 0 = all images
        end

        # --- Query Building ---

        def build_search_query(params, api_id)
          lang_code = lang_code_for(params[:locale])

          query = {
            p1: p1_constant,
            p2: api_key,
            p_apiid: api_id,
            p_PageSize: params[:per_page] || 24,
            P_Lang: lang_code,
            P_Country: default_country,
            P_Images: image_count,
            p_MustHaveFeatures: "2",
            p_new_devs: params[:new_developments_only] ? "only" : "include"
          }

          # Pagination
          query[:p_PageNo] = params[:page] if params[:page] && params[:page] > 1

          # Sort
          if params[:sort]
            query[:p_SortType] = SORT_OPTIONS[params[:sort].to_sym] || "0"
          end

          # Property types
          if params[:property_types]&.any?
            types = params[:property_types].is_a?(Array) ? params[:property_types] : [params[:property_types]]
            query[:p_PropertyTypes] = types.join(",")
          end

          # Location
          query[:p_Location] = params[:location] if params[:location].present?

          # Bedrooms (use "Nx" format for "at least N")
          query[:p_Beds] = "#{params[:min_bedrooms]}x" if params[:min_bedrooms]

          # Bathrooms
          query[:p_Baths] = "#{params[:min_bathrooms]}x" if params[:min_bathrooms]

          # Price range (API expects whole units, not cents)
          query[:p_Min] = params[:min_price] if params[:min_price]
          query[:p_Max] = params[:max_price] if params[:max_price]

          # Features
          if params[:features]&.any?
            feature_mappings = config[:features] || {}
            params[:features].each do |feature|
              if feature_mappings[feature.to_s]
                query[feature_mappings[feature.to_s][:param]] = "1"
              else
                query[feature] = "1"
              end
            end
          end

          URI.encode_www_form(query)
        end

        # --- HTTP ---

        def fetch_json(url)
          # Use Addressable for proper URL encoding (handles accented characters)
          uri = URI.parse(Addressable::URI.escape(url))

          response = uri.open(
            redirect: false,
            read_timeout: 30,
            open_timeout: 10
          )

          JSON.parse(response.read)
        rescue OpenURI::HTTPRedirect => redirect
          # Follow redirect once
          URI.parse(redirect.uri.to_s).open(redirect: false) { |r| JSON.parse(r.read) }
        rescue OpenURI::HTTPError => e
          handle_http_error(e)
        rescue JSON::ParserError => e
          raise InvalidResponseError, "Invalid JSON from Resales API: #{e.message}"
        rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout
          raise ProviderUnavailableError, "Resales API request timed out"
        rescue StandardError => e
          log(:error, "Fetch error: #{e.class} - #{e.message}")
          raise ProviderUnavailableError, "Failed to fetch from Resales API: #{e.message}"
        end

        def handle_http_error(error)
          code = error.io.status[0]
          case code
          when "401", "403"
            raise AuthenticationError, "Resales API authentication failed (#{code})"
          when "429"
            raise RateLimitError, "Resales API rate limit exceeded"
          when "404"
            raise PropertyNotFoundError, "Property not found"
          when "500", "502", "503", "504"
            raise ProviderUnavailableError, "Resales API server error (#{code})"
          else
            raise Error, "Resales API HTTP error: #{code}"
          end
        end

        # --- Response Normalization ---

        def normalize_search_results(response, params)
          unless response.dig("transaction", "status") == "success"
            error_msg = response.dig("transaction", "message") || "Search failed"
            raise Error, "Resales API error: #{error_msg}"
          end

          properties_data = response["Property"]
          properties_data = [] if properties_data.nil?
          properties_data = [properties_data] if properties_data.is_a?(Hash)

          properties = properties_data.map do |prop|
            normalize_property(prop, params)
          end

          NormalizedSearchResult.new(
            properties: properties,
            total_count: response.dig("QueryInfo", "PropertyCount").to_i,
            page: response.dig("QueryInfo", "CurrentPage")&.to_i || params[:page] || 1,
            per_page: response.dig("QueryInfo", "PropertiesPerPage")&.to_i || params[:per_page] || 24,
            provider: self.class.provider_name,
            query_params: params
          )
        end

        def normalize_property(data, params = {})
          listing_type = params[:listing_type] || :sale

          NormalizedProperty.new(
            reference: data["Reference"],
            provider: self.class.provider_name,
            provider_url: nil,

            title: build_title(data),
            description: data["Description"],
            property_type: normalize_type(data["Type"]),
            property_type_raw: data.dig("PropertyType", "SubtypeId1") || data["TypeId"],
            property_subtype: data.dig("PropertyType", "Subtype1") || data["Type"],

            country: data["Country"],
            region: data["Province"],
            area: data["Area"],
            city: data["Location"],
            latitude: data.dig("GeoData", "Latitude")&.to_f || data["Latitude"]&.to_f,
            longitude: data.dig("GeoData", "Longitude")&.to_f || data["Longitude"]&.to_f,

            listing_type: listing_type,
            status: normalize_status(data.dig("Status", "system")),
            price: (data["Price"].to_f * 100).to_i,
            price_raw: data["Price"].to_s,
            currency: data["Currency"] || "EUR",
            original_price: data["OriginalPrice"] ? (data["OriginalPrice"].to_f * 100).to_i : nil,

            bedrooms: data["Bedrooms"].to_i,
            bathrooms: data["Bathrooms"].to_f,
            built_area: data["Built"].to_i,
            plot_area: data["GardenPlot"].to_i,
            terrace_area: data["Terrace"].to_i,

            features: extract_features(data),
            features_by_category: extract_features_by_category(data),

            energy_rating: data.dig("EnergyRating", "EnergyRated"),
            energy_value: data.dig("EnergyRating", "EnergyValue")&.to_f,
            co2_rating: data.dig("EnergyRating", "CO2Rated"),

            images: normalize_images(data),
            virtual_tour_url: data["VirtualTour"],

            community_fees: data["Community_Fees_Year"] ? (data["Community_Fees_Year"].to_f * 100).to_i : nil,
            ibi_tax: data["IBI_Fees_Year"] ? (data["IBI_Fees_Year"].to_f * 100).to_i : nil
          )
        end

        def build_title(data)
          # Build title from available data
          type = data["Type"] || "Property"
          location = data["Location"]
          bedrooms = data["Bedrooms"]

          parts = []
          parts << "#{bedrooms} Bedroom" if bedrooms && bedrooms.to_i > 0
          parts << type
          parts << "in #{location}" if location.present?

          parts.join(" ")
        end

        def normalize_type(type)
          return "other" if type.blank?

          type_lower = type.to_s.downcase
          case type_lower
          when /penthouse/
            "penthouse"
          when /top floor|top-floor/
            "apartment_top"
          when /ground floor|ground-floor/
            "apartment_ground"
          when /middle floor|middle-floor/
            "apartment_middle"
          when /apartment|flat|duplex/
            "apartment"
          when /villa|detached/
            "villa"
          when /townhouse|town house|town-house|terraced/
            "townhouse"
          when /semi-detached|semi detached|semidetached/
            "semi_detached"
          when /bungalow/
            "bungalow"
          when /finca|cortijo|country/
            "finca"
          when /plot|land/
            "land"
          when /commercial|office|retail|shop/
            "commercial"
          else
            "other"
          end
        end

        def normalize_status(status)
          case status
          when "Available"
            :available
          when "Reserved"
            :reserved
          when "Sold"
            :sold
          when "Off Market"
            :unavailable
          else
            :available
          end
        end

        def normalize_images(data)
          pictures = data.dig("Pictures", "Picture")
          return [] unless pictures

          pictures = [pictures] if pictures.is_a?(Hash)

          pictures.map.with_index do |pic, idx|
            {
              url: pic["PictureURL"],
              caption: nil,
              position: idx
            }
          end
        end

        def extract_features(data)
          categories = data.dig("PropertyFeatures", "Category")
          return [] unless categories

          categories = [categories] if categories.is_a?(Hash)

          categories.flat_map do |cat|
            values = cat["Value"]
            values.is_a?(Array) ? values : [values]
          end.compact
        end

        def extract_features_by_category(data)
          categories = data.dig("PropertyFeatures", "Category")
          return {} unless categories

          categories = [categories] if categories.is_a?(Hash)

          categories.each_with_object({}) do |cat, hash|
            category_name = cat.dig("@attributes", "Type") || "Other"
            values = cat["Value"]
            values = values.is_a?(Array) ? values : [values]
            hash[category_name] = values.compact
          end
        end

        # --- Default Data ---

        def default_locations
          [
            { value: "Marbella", label: "Marbella" },
            { value: "Estepona", label: "Estepona" },
            { value: "Benahavis", label: "Benahavís" },
            { value: "Mijas", label: "Mijas" },
            { value: "Fuengirola", label: "Fuengirola" },
            { value: "Benalmadena", label: "Benalmádena" },
            { value: "Torremolinos", label: "Torremolinos" },
            { value: "Malaga", label: "Málaga" },
            { value: "Nerja", label: "Nerja" },
            { value: "Casares", label: "Casares" },
            { value: "Manilva", label: "Manilva" },
            { value: "Sotogrande", label: "Sotogrande" },
            { value: "Puerto Banus", label: "Puerto Banús" },
            { value: "Nueva Andalucia", label: "Nueva Andalucía" },
            { value: "San Pedro de Alcantara", label: "San Pedro de Alcántara" },
            { value: "La Cala de Mijas", label: "La Cala de Mijas" },
            { value: "Mijas Costa", label: "Mijas Costa" },
            { value: "Mijas Pueblo", label: "Mijas Pueblo" },
            { value: "Calahonda", label: "Calahonda" },
            { value: "Riviera del Sol", label: "Riviera del Sol" }
          ]
        end

        def default_property_types
          [
            {
              value: "1-1",
              label: "Apartment",
              subtypes: [
                { value: "1-2", label: "Ground Floor Apartment" },
                { value: "1-4", label: "Middle Floor Apartment" },
                { value: "1-5", label: "Top Floor Apartment" },
                { value: "1-6", label: "Penthouse" },
                { value: "1-7", label: "Duplex" }
              ]
            },
            {
              value: "2-1",
              label: "House",
              subtypes: [
                { value: "2-2", label: "Detached Villa" },
                { value: "2-4", label: "Semi-Detached House" },
                { value: "2-5", label: "Townhouse" },
                { value: "2-6", label: "Finca / Country House" }
              ]
            },
            { value: "3-1", label: "Plot / Land" },
            { value: "4-1", label: "Commercial" }
          ]
        end
      end
    end
  end
end
