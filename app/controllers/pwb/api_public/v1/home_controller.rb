require_dependency "pwb/application_controller"

module Pwb
  class ApiPublic::V1::HomeController < ApplicationApiController

    def index
      locale = "en"
      current_page = Pwb::Page.find_by_slug "home"
      current_page_title = @current_agency.company_name
      # @content_to_show = []

      if current_page.present?
        if current_page.page_title.present?
          current_page_title = current_page.page_title + ' - ' + @current_agency.company_name.to_s
        end


        public_page_parts = {}
        current_page.page_parts.each do |page_part|
          public_page_parts[page_part.page_part_key] = page_part.block_contents[locale]
        end


        @properties_for_sale = Prop.for_sale.visible.order('highlighted DESC').limit 9
        @properties_for_rent = Prop.for_rent.visible.order('highlighted DESC').limit 9

        # @search_defaults = params[:search].present? ? params[:search] : {}

        return render json: {
          page_parts: public_page_parts,
          page: current_page.as_json_for_fe
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
