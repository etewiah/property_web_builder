module Pwb
  class Api::V1::LitePropertiesController < ApplicationController
    protect_from_forgery with: :null_session
    before_action :set_current_website
    before_action :check_authentication

    # GET /api/v1/lite-properties
    def index
      properties = current_properties
      properties = properties.where(visible: params.dig(:filter, :visible)) if params.dig(:filter, :visible).present?

      render json: serialize_properties(properties)
    end

    # GET /api/v1/lite-properties/:id
    def show
      property = current_properties.find(params[:id])
      render json: serialize_property(property)
    end

    private

    def current_properties
      if Pwb::Current.website
        Pwb::ListedProperty.where(website_id: Pwb::Current.website.id)
      else
        Pwb::ListedProperty.none
      end
    end

    def serialize_properties(properties)
      {
        data: properties.map { |p| serialize_property_data(p) }
      }
    end

    def serialize_property(property)
      {
        data: serialize_property_data(property)
      }
    end

    def serialize_property_data(property)
      {
        id: property.id.to_s,
        type: "lite-properties",
        attributes: {
          "year-construction" => property.year_construction,
          "prop-type-key" => property.prop_type_key,
          "prop-state-key" => property.prop_state_key,
          "prop-origin-key" => property.prop_origin_key,
          "count-bedrooms" => property.count_bedrooms,
          "count-bathrooms" => property.count_bathrooms,
          "count-toilets" => property.count_toilets,
          "count-garages" => property.count_garages,
          "constructed-area" => property.constructed_area,
          "plot-area" => property.plot_area,
          # Legacy attribute names for backwards compatibility
          "property-type-key" => property.prop_type_key,
          "num-habitaciones" => property.count_bedrooms,
          "num-banos" => property.count_bathrooms,
          "visible" => property.visible,
          "highlighted" => property.highlighted,
          "reference" => property.reference
        }
      }
    end

    def set_current_website
      Pwb::Current.website = current_website_from_subdomain
    end

    def current_website_from_subdomain
      return nil unless request.subdomain.present?
      Website.find_by_subdomain(request.subdomain)
    end

    def bypass_authentication?
      ENV['BYPASS_API_AUTH'] == 'true'
    end

    def check_authentication
      return true if bypass_authentication?

      authenticate_user!
      check_user_is_admin
    end

    def check_user_is_admin
      unless current_user && current_user.admin_for?(Pwb::Current.website)
        render json: { errors: [{ detail: "unauthorised_user" }] }, status: :unprocessable_entity
      end
    end
  end
end
