require_dependency "pwb/application_controller"

module Pwb
  class ApiPublic::V1::PropertiesController < ApplicationApiController

    def show
      I18n.locale = params[:locale]
      property = Pwb::Prop.find params[:id]
      # property_title = @current_agency.company_name
      # @content_to_show = []

      if property.present?

        return render json: {
          property: property.as_json_detailed
        }
      else
        return render json: {
          page: {}
        }
      end
    end


    private

  end
end
