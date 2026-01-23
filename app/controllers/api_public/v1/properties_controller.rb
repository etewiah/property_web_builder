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
        render_not_found_error("Property not found", code: "PROPERTY_NOT_FOUND")
      end

      def search
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale

        # Handle grouped response for landing page optimization
        if params[:group_by] == 'sale_or_rental'
          return render_grouped_properties
        end

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
        render_not_found_error("Property not found", code: "PROPERTY_NOT_FOUND")
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

      # Render properties grouped by sale/rental type
      # GET /api_public/v1/properties?group_by=sale_or_rental&per_group=3&featured=true
      # Returns: { sale: { properties: [...], meta: {} }, rental: { properties: [...], meta: {} } }
      def render_grouped_properties
        per_group = (params[:per_group] || params[:per_page] || 3).to_i
        featured_only = params[:featured] == 'true' || params[:highlighted] == 'true'

        base_scope = Pwb::Current.website.listed_properties
        base_scope = base_scope.where(highlighted: true) if featured_only

        # Build common search args (without sale_or_rental)
        common_args = {
          currency: params[:currency] || "usd",
          for_sale_price_from: params[:for_sale_price_from] || "none",
          for_sale_price_till: params[:for_sale_price_till] || "none",
          for_rent_price_from: params[:for_rent_price_from] || "none",
          for_rent_price_till: params[:for_rent_price_till] || "none",
          bedrooms_from: params[:bedrooms_from] || "none",
          bathrooms_from: params[:bathrooms_from] || "none",
          property_type: params[:property_type] || "none"
        }

        # Fetch sale properties
        sale_args = common_args.merge(sale_or_rental: "sale")
        sale_scope = base_scope.properties_search(**sale_args)
        sale_scope = apply_sorting(sale_scope, params[:sort_by] || params[:sort])
        sale_total = sale_scope.count
        sale_properties = sale_scope.limit(per_group)

        # Fetch rental properties
        rental_args = common_args.merge(sale_or_rental: "rental")
        rental_scope = base_scope.properties_search(**rental_args)
        rental_scope = apply_sorting(rental_scope, params[:sort_by] || params[:sort])
        rental_total = rental_scope.count
        rental_properties = rental_scope.limit(per_group)

        # Short cache for grouped results
        set_short_cache(max_age: 2.minutes)

        render json: {
          sale: {
            properties: sale_properties.map { |p| property_response(p, summary: true) },
            meta: { total: sale_total, per_group: per_group }
          },
          rental: {
            properties: rental_properties.map { |p| property_response(p, summary: true) },
            meta: { total: rental_total, per_group: per_group }
          }
        }
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

        # Include page_contents with similar properties for detail view (not summary)
        unless summary
          json[:page_contents] = build_page_contents(property)
        end

        json
      end

      # Build page_contents array for property detail view
      # Mirrors structure from LocalizedPagesController
      def build_page_contents(property)
        [
          build_similar_properties_part(property)
        ]
      end

      # Build similar properties page part
      def build_similar_properties_part(property)
        {
          page_part_key: "summary_listings_part/similar_properties",
          sort_order: 888,
          visible: true,
          is_rails_part: false,
          rendered_html: nil,
          label: I18n.t('similarProperties', default: 'Similar properties'),
          summ_listings: fetch_similar_properties(property)
        }
      end

      # Fetch properties similar to the given property
      # Similarity criteria:
      # - Same sale/rental type
      # - Same city or region (if available)
      # - Excludes the current property
      def fetch_similar_properties(property, limit: 6)
        base_scope = Pwb::Current.website.listed_properties.where.not(id: property.id)

        # Determine sale or rental type
        sale_or_rental = property.for_sale? ? "sale" : "rental"

        # Start with same sale/rental type
        scope = base_scope.properties_search(
          sale_or_rental: sale_or_rental,
          currency: property.currency || "usd",
          for_sale_price_from: "none",
          for_sale_price_till: "none",
          for_rent_price_from: "none",
          for_rent_price_till: "none",
          bedrooms_from: "none",
          bathrooms_from: "none",
          property_type: "none"
        )

        # Prioritize same city
        if property.city.present?
          city_matches = scope.where(city: property.city).limit(limit)
          return city_matches.map { |p| property_summary_json(p) } if city_matches.count >= 3
        end

        # Fall back to same region
        if property.region.present?
          region_matches = scope.where(region: property.region).limit(limit)
          return region_matches.map { |p| property_summary_json(p) } if region_matches.count >= 3
        end

        # Fall back to any properties of same type
        scope.limit(limit).map { |p| property_summary_json(p) }
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
          prop_photos: serialize_prop_photos(property, limit: 3)
        }.compact
      end

      # Serialize prop_photos with variants for API responses
      # Matches logic in ListedProperty#as_json for consistency
      def serialize_prop_photos(property, limit: 3)
        return [] unless property.respond_to?(:prop_photos)

        property.prop_photos.first(limit).filter_map do |photo|
          next unless photo.has_image?

          if photo.external?
            {
              id: photo.id,
              url: photo.external_url,
              alt: photo.respond_to?(:caption) ? photo.caption.presence : nil,
              position: photo.sort_order,
              variants: build_external_variants(photo.external_url)
            }
          elsif photo.image.attached?
            {
              id: photo.id,
              url: photo_url(photo.image),
              alt: photo.respond_to?(:caption) ? photo.caption.presence : nil,
              position: photo.sort_order,
              variants: generate_photo_variants(photo.image)
            }
          end
        end
      end

      def photo_url(image)
        Rails.application.routes.url_helpers.rails_blob_url(
          image,
          **asset_url_options
        )
      rescue StandardError
        nil
      end

      def generate_photo_variants(image)
        return {} unless image.variable?

        {
          thumbnail: variant_url_for(image, resize_to_limit: [150, 100]),
          small: variant_url_for(image, resize_to_limit: [300, 200]),
          medium: variant_url_for(image, resize_to_limit: [600, 400]),
          large: variant_url_for(image, resize_to_limit: [1200, 800])
        }
      rescue StandardError
        {}
      end

      def variant_url_for(image, transformations)
        Rails.application.routes.url_helpers.rails_representation_url(
          image.variant(transformations).processed,
          **asset_url_options
        )
      rescue StandardError
        nil
      end

      # Returns URL options for Active Storage URLs
      # Handles CDN hosts properly by parsing and extracting host, port, and protocol
      # Explicitly sets port to override Rails.application.routes.default_url_options
      def asset_url_options
        asset_host = ENV['ASSET_HOST'].presence ||
                     ENV['APP_HOST'].presence ||
                     Rails.application.config.action_controller.asset_host

        if asset_host.present?
          uri = URI.parse(asset_host)
          scheme = uri.scheme || 'https'
          # Explicitly set port to override default_url_options[:port]
          # Use nil for default ports (443 for https, 80 for http) to omit port from URL
          explicit_port = if uri.port && uri.port != uri.default_port
                            uri.port
                          end
          {
            host: uri.host || asset_host,
            port: explicit_port,
            protocol: scheme
          }
        else
          { host: request.host_with_port }
        end
      rescue URI::InvalidURIError
        { host: asset_host }
      end
    end
  end
end
