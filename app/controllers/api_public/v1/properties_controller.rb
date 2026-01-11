module ApiPublic
  module V1
    class PropertiesController < BaseController
      # TODO: Add authentication if needed, similar to other API controllers

      def show
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale
        # Use listed_properties (materialized view) instead of deprecated props
        scope = Pwb::Current.website.listed_properties
        property = scope.find_by(slug: params[:id]) || scope.find_by(id: params[:id])
        raise ActiveRecord::RecordNotFound unless property
        render json: property.as_json
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
        if params[:highlighted] == 'true'
          properties = properties.where(highlighted: true)
        end

        # Apply limit if specified
        if params[:limit].present?
          properties = properties.limit(params[:limit].to_i)
        end

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

        render json: {
          data: paginated_properties.as_json,
          map_markers: map_markers,
          meta: {
            total: total_count,
            page: page,
            per_page: per_page,
            total_pages: total_pages
          }
        }
      end
    end
  end
end
