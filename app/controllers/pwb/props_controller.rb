require_dependency "pwb/application_controller"

module Pwb
  class PropsController < ApplicationController

    def show_for_rent
      # @inmo_template = "broad"
      @property_details = Prop.find_by_id(params[:id])
      # gon.property_details =@property_details
      @operation_type = "for_rent"
      if @property_details && @property_details.visible && @property_details.for_rent
        # below lets me know what prices to display
        @show_vacational_rental = @property_details.for_rent_short_term

        # js :property_details => @property_details
        # js :show
        # page_title gets picked up automatically by meta-tags gem
        @page_title = @property_details.title
        @page_description = @property_details.description
        # @page_keywords    = 'Site, Login, Members'
        return render "show"
      else
        return render "not_found"
      end
    end

    def show_for_sale
      # @inmo_template = "broad"
      @operation_type = "for_sale"
      @property_details = Prop.find_by_id(params[:id])

      if @property_details && @property_details.visible && @property_details.for_sale
        # gon.property_details =@property_details

        # js :property_details => @property_details
        # js :show
        @page_title = @property_details.title
        @page_description = @property_details.description
        # @page_keywords    = 'Site, Login, Members'
        return render @current_agency.views_folder + "/props/show"
      else
        return render "not_found"
      end
    end

  end
end
