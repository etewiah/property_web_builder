# frozen_string_literal: true

module ApiPublic
  module V1
    # WidgetsController handles API requests for embeddable property widgets
    #
    # This controller provides:
    # - Widget configuration endpoint (theme, layout, settings)
    # - Properties endpoint optimized for widget display
    # - Impression/click tracking
    #
    # All responses include CORS headers for cross-origin embedding.
    class WidgetsController < BaseController
      before_action :set_widget_config
      before_action :validate_origin

      # GET /api_public/v1/widgets/:widget_key
      # Returns widget configuration and initial properties
      def show
        properties = fetch_properties

        render json: {
          config: @widget_config.as_widget_config,
          properties: serialize_properties(properties),
          total_count: properties.size,
          website: {
            name: current_website.company_display_name,
            currency: current_website.default_currency || 'EUR',
            area_unit: current_website.default_area_unit || 'sqmt'
          }
        }
      end

      # GET /api_public/v1/widgets/:widget_key/properties
      # Returns properties for the widget (with pagination)
      def properties
        page = (params[:page] || 1).to_i
        per_page = [@widget_config.max_properties, 50].min

        properties = fetch_properties
        total_count = properties.size

        # Simple offset pagination
        offset = (page - 1) * per_page
        paginated = properties.offset(offset).limit(per_page)

        render json: {
          properties: serialize_properties(paginated),
          pagination: {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil
          }
        }
      end

      # POST /api_public/v1/widgets/:widget_key/impression
      # Track widget impression (loaded on page)
      def impression
        @widget_config.record_impression!
        head :ok
      end

      # POST /api_public/v1/widgets/:widget_key/click
      # Track property click
      def click
        @widget_config.record_click!
        head :ok
      end

      private

      def set_widget_config
        @widget_config = Pwb::WidgetConfig.active.find_by!(widget_key: params[:widget_key])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Widget not found' }, status: :not_found
      end

      def current_website
        @widget_config.website
      end

      def validate_origin
        origin = request.headers['Origin'] || request.headers['Referer']
        return if origin.blank? # Allow direct API access

        domain = extract_domain(origin)
        return if @widget_config.domain_allowed?(domain)

        # Log unauthorized access attempt
        Rails.logger.warn "Widget #{@widget_config.widget_key} accessed from unauthorized domain: #{domain}"

        # Still allow for now but could block in future
        # render json: { error: 'Origin not allowed' }, status: :forbidden
      end

      def extract_domain(url)
        URI.parse(url).host
      rescue URI::InvalidURIError
        nil
      end

      def fetch_properties
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale

        @widget_config.properties_query.with_eager_loading
      end

      def serialize_properties(properties)
        visible = @widget_config.effective_visible_fields

        properties.map do |prop|
          serialize_property(prop, visible)
        end
      end

      def serialize_property(prop, visible_fields)
        data = {
          id: prop.id,
          title: prop.title,
          url: property_url(prop)
        }

        # Primary photo
        first_photo = prop.prop_photos.first
        data[:photo_url] = first_photo&.thumbnail_url(size: [400, 300])
        data[:photo_count] = prop.prop_photos.size

        # Conditional fields based on widget config
        if visible_fields['price']
          data[:price] = format_price(prop)
          data[:price_raw] = prop.for_sale ? prop.price_sale_current_cents : prop.price_rental_monthly_current_cents
          data[:currency] = prop.for_sale ? prop.price_sale_current_currency : prop.price_rental_monthly_current_currency
        end

        data[:bedrooms] = prop.count_bedrooms if visible_fields['bedrooms']
        data[:bathrooms] = prop.count_bathrooms if visible_fields['bathrooms']

        if visible_fields['area']
          data[:area] = prop.constructed_area
          data[:area_unit] = prop.area_unit
        end

        data[:location] = prop.city if visible_fields['location']
        data[:reference] = prop.reference if visible_fields['reference']
        data[:property_type] = prop.prop_type_key&.split('.')&.last if visible_fields['property_type']

        # Listing type indicators
        data[:for_sale] = prop.for_sale
        data[:for_rent] = prop.for_rent
        data[:highlighted] = prop.highlighted

        data
      end

      def property_url(prop)
        # Generate URL to the property on the main website
        if prop.for_sale
          Rails.application.routes.url_helpers.prop_show_for_sale_url(
            id: prop.id,
            url_friendly_title: prop.url_friendly_title,
            host: @widget_config.website.primary_host || "#{@widget_config.website.subdomain}.propertywebbuilder.com",
            protocol: 'https'
          )
        else
          Rails.application.routes.url_helpers.prop_show_for_rent_url(
            id: prop.id,
            url_friendly_title: prop.url_friendly_title,
            host: @widget_config.website.primary_host || "#{@widget_config.website.subdomain}.propertywebbuilder.com",
            protocol: 'https'
          )
        end
      end

      def format_price(prop)
        if prop.for_sale && prop.price_sale_current_cents.present?
          currency = prop.price_sale_current_currency || 'EUR'
          Money.new(prop.price_sale_current_cents, currency).format
        elsif prop.for_rent && prop.price_rental_monthly_current_cents.present?
          currency = prop.price_rental_monthly_current_currency || 'EUR'
          "#{Money.new(prop.price_rental_monthly_current_cents, currency).format}/mo"
        end
      end
    end
  end
end
