module ApiPublic
  module V1
    class PropertiesController < BaseController
      # TODO: Add authentication if needed, similar to other API controllers

      def show
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale
        # Use Pwb::Prop directly to match Rails controller behavior
        property = Pwb::Prop.find(params[:id])
        render json: property.as_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Property not found" }, status: :not_found
      end

      def search
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

        # Use Pwb::Prop directly like the Rails SearchController does
        # (properties currently have nil website_id)
        properties = Pwb::Prop.properties_search(**args)
        render json: properties.as_json
      end
    end
  end
end
