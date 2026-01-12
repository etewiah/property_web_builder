module ApiPublic
  module V1
    class PropertiesController < BaseController
      include ApiPublic::Cacheable
      include ApiPublic::ImageVariants

      def show
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale
        # Use listed_properties (materialized view) instead of deprecated props
        scope = Pwb::Current.website.listed_properties
        property = scope.find_by(slug: params[:id]) || scope.find_by(id: params[:id])
        raise ActiveRecord::RecordNotFound unless property

        set_short_cache(max_age: 5.minutes, etag_data: [property.id, property.updated_at])
        return if performed?

        render json: property_response(property)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Property not found" }, status: :not_found
      end

      def search
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale

        # Default values matching GraphQL implementation
        args = {
          sale_or_rental: params[:sale_or_rental] || "sale",
          currency: params[:currency] || "usd",
          for_sale_price_from: params[:for_sale_price_from] || "none",
          for_sale_price_till: params[:for_sale_price_till] || "none",
          for_rent_price_from: params[:for_rent_price_from] || "none",
          for_rent_price_till: params[:for_rent_price_till] || "none",
          bedrooms_from: params[:bedrooms_from] || "none",
          bathrooms_from: params[:bathrooms_from] || "none",
          property_type: params[:property_type] || "none"
        }

        # Use listed_properties (materialized view) instead of deprecated props
        properties = Pwb::Current.website.listed_properties.properties_search(**args)

        # Filter by highlighted/featured if requested
        properties = properties.where(highlighted: true) if params[:highlighted] == 'true' || params[:featured] == 'true'

        # Sorting support for API clients
        properties = apply_sorting(properties, params[:sort_by] || params[:sort])

        # Apply limit if specified
        properties = properties.limit(params[:limit].to_i) if params[:limit].present?

        # Pagination support
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 12).to_i

        # Simple pagination using offset/limit
        total_count = properties.count
        total_pages = (total_count.to_f / per_page).ceil
        paginated_properties = properties.offset((page - 1) * per_page).limit(per_page)

        # Generate map markers
        map_markers = paginated_properties.map do |prop|
          next unless prop.latitude.present? && prop.longitude.present?

          {
            id: prop.id,
            slug: prop.slug,
            lat: prop.latitude,
            lng: prop.longitude,
            title: prop.title,
            price: prop.formatted_price,
            image: prop.primary_image_url,
            url: "/properties/#{prop.slug}"
          }
        end.compact

        # Short cache for search results
        set_short_cache(max_age: 2.minutes)

        render json: {
          data: paginated_properties.map { |p| property_response(p, summary: true) },
          map_markers: map_markers,
          meta: {
            total: total_count,
            page: page,
            per_page: per_page,
            total_pages: total_pages
          }
        }
      end

      # GET /api_public/v1/properties/:id/schema
      # Returns JSON-LD structured data for SEO
      def schema
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale

        scope = Pwb::Current.website.listed_properties
        property = scope.find_by(slug: params[:id]) || scope.find_by(id: params[:id])
        raise ActiveRecord::RecordNotFound unless property

        set_long_cache(max_age: 1.hour, etag_data: [property.id, property.updated_at])
        return if performed?

        render json: build_json_ld(property)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Property not found" }, status: :not_found
      end

      private

      def apply_sorting(scope, sort_param)
        return scope if sort_param.blank?

        case sort_param
        when 'price-asc', 'price_asc'
          scope.order(price_sale_current_cents: :asc, price_rental_monthly_current_cents: :asc)
        when 'price-desc', 'price_desc'
          scope.order(price_sale_current_cents: :desc, price_rental_monthly_current_cents: :desc)
        when 'newest', 'date-desc', 'date_desc'
          scope.order(created_at: :desc)
        when 'oldest', 'date-asc', 'date_asc'
          scope.order(created_at: :asc)
        else
          scope
        end
      end

      def build_json_ld(property)
        website = Pwb::Current.website

        {
          '@context': "https://schema.org",
          '@type': "RealEstateListing",
          name: property.title,
          description: strip_tags(property.description).to_s.truncate(500),
          url: "#{request.protocol}#{request.host_with_port}/properties/#{property.slug}",
          datePosted: property.created_at&.iso8601,
          offers: {
            '@type': "Offer",
            price: property_price(property),
            priceCurrency: property.respond_to?(:currency) ? property.currency : "EUR",
            availability: "https://schema.org/InStock"
          },
          address: {
            '@type': "PostalAddress",
            streetAddress: property.respond_to?(:address) ? property.address : nil,
            addressLocality: property.locality,
            addressRegion: property.zone,
            addressCountry: property.respond_to?(:country_code) ? property.country_code : nil
          }.compact,
          geo: if property.latitude.present?
                 {
                   '@type': "GeoCoordinates",
                   latitude: property.latitude,
                   longitude: property.longitude
                 }
               else
                 nil
               end,
          image: property_images(property),
          numberOfRooms: property.count_bedrooms,
          numberOfBathroomsTotal: property.count_bathrooms,
          floorSize: if property.respond_to?(:plot_area) && property.plot_area.present?
                       {
                         '@type': "QuantitativeValue",
                         value: property.plot_area,
                         unitCode: "MTK"
                       }
                     else
                       nil
                     end
        }.compact
      end

      def property_price(property)
        if property.respond_to?(:price_sale_current_cents) && property.price_sale_current_cents.present?
          property.price_sale_current_cents / 100
        elsif property.respond_to?(:price_rental_monthly_current_cents) && property.price_rental_monthly_current_cents.present?
          property.price_rental_monthly_current_cents / 100
        else
          nil
        end
      end

      def property_images(property)
        return [] unless property.respond_to?(:photo_urls)

        property.photo_urls.first(10)
      rescue StandardError
        []
      end

      def strip_tags(html)
        ActionController::Base.helpers.strip_tags(html)
      end

      # Build property JSON response, optionally including image variants
      # @param property [Object] The property record
      # @param summary [Boolean] If true, returns abbreviated data for list views
      # @return [Hash] Property JSON representation
      def property_response(property, summary: false)
        include_images = params[:include_images]

        json = summary ? property_summary_json(property) : property.as_json

        # Include image variants if requested
        if include_images == "variants" && property.respond_to?(:prop_photos)
          json[:images] = images_with_variants(property.prop_photos, limit: summary ? 3 : 10)
        end

        json
      end

      # Abbreviated property data for list views
      def property_summary_json(property)
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
          count_garages: property.count_garages,
          highlighted: property.highlighted,
          for_sale: property.for_sale?,
          for_rent: property.for_rent?,
          primary_image_url: property.primary_image_url,
          prop_photos: property.try(:prop_photos)&.first(3)&.map { |p| { image: p.try(:image_url) || p.try(:url) } }
        }.compact
      end
    end
  end
end
