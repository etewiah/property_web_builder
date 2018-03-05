require_dependency "pwb/application_controller"

module Pwb
  class ApiPublic::V1::PropertiesController < ApplicationApiPublicController

    def search
      @operation_type = "for_rent"
      # http://www.justinweiss.com/articles/search-and-filter-rails-models-without-bloating-your-controller/

      # @properties = Prop.visible.for_rent
      # apply_search_filter filtering_params(params)
      # set_map_markers
      # render "/pwb/search/search_ajax.js.erb", layout: false

      # byebug

      prop_search_results = DisplayPropertiesQuery.new(search_params: params).from_params
      # else
      #   prop_search_results = DisplayPropertiesQuery.new().from_params
      # end
      # properties_for_rent = DisplayPropertiesQuery.new().for_rent

      return render json: {
        prop_search_results: prop_search_results
      }
    end


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
