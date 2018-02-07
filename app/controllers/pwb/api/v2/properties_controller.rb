require_dependency "pwb/application_controller"

module Pwb
  class Api::V2::PropertiesController < ApplicationApiController

    def index
      @properties = Prop.all.limit(100)
      render json: @properties
    end


    def show
      @property = Prop.find(params[:id])
      render json: @property
    end

    def update
      @property = Prop.find(params[:id])
      @property.update(property_params)
      @property.save!
      render json: @property
    end

    def property_params
      params.require(:property).permit(
        :title,
        :street_address, :street_number,
        :postal_code, :city,
        :region, :country,
        :longitude, :latitude
      )
    end
  end
end
