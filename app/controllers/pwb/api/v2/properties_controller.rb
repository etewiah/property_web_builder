require_dependency "pwb/application_controller"

module Pwb
  class Api::V2::PropertiesController < ApplicationApiController

    def index
      @properties = Prop.all.limit(100)
      render json: @properties
    end


    def show
      @property = Prop.find(params[:id])
      render json: @property.as_json_for_admin
    end

    def update
      @property = Prop.find(params[:id])
      @property.update(property_params)
      @property.save!
      render json: @property.as_json_for_admin
    end

    def update_features
      property = Prop.find(params[:id])
      property.set_features = params[:features].to_unsafe_hash
      # The set_features method goes through each feature to ensure it
      # is valid so okay to byepass strong params as above
      property.save!
      return render json: property.features_list
    end

    def create
      # TODO - use prop_creator service object for below 
      # so that I can control geocoding, default settings etc..
      @property = Pwb::Prop.create create_property_params
      render json: @property.as_json_for_admin
    end

    private

    def create_property_params
      params.require(:new_property).permit(
        :reference, :title,
        :prop_type_key, :prop_state_key, :prop_origin_key,
      )
    end

    def property_params
      permitted = Prop.globalize_attribute_names +
        [:street_address, :street_number, :street_name,
         :postal_code, :city,
         :region, :country,
         :longitude, :latitude,
         :area_unit, :currency, :prop_photos, :features,
         :count_bathrooms, :count_bedrooms, :count_garages, :count_toilets,
         :constructed_area, :year_construction, :plot_area,
         :prop_type_key, :prop_state_key, :prop_origin_key,
         :for_sale, :for_rent_short_term, :for_rent_long_term, :obscure_map, :hide_map,
         # :price_sale_current_cents, :price_sale_original_cents,
         # :price_rental_monthly_current_cents, :price_rental_monthly_original_cents,
         # :price_rental_monthly_low_season_cents, :price_rental_monthly_high_season_cents,
         # :price_rental_monthly_standard_season_cents,
         :visible, :highlighted, :reference,
         :price_rental_monthly_current_cents, :price_sale_current_cents,
         :price_sale_original_cents, :price_rental_monthly_current_cents,
         :price_rental_monthly_original_cents, :price_rental_monthly_low_season_cents,
         :price_rental_monthly_high_season_cents, :price_rental_monthly_standard_season_cents,
         ]
      params.require(:property).permit(
        *permitted
      )
    end
  end
end
