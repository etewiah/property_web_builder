require_dependency "pwb/application_controller"

module Pwb
  class ApiPublic::V1::PagesController < ApplicationApiPublicController

    def show
      locale = params[:locale]
      I18n.locale = locale
      current_page = Pwb::Page.find_by_slug params[:page_slug]
      # current_page_title = @current_agency.company_name

      if current_page.present?
        # if current_page.page_title.present?
        #   current_page_title = current_page.page_title + ' - ' + @current_agency.company_name.to_s
        # end


        public_page_parts = {}
        current_page.page_parts.each do |page_part|
          public_page_parts[page_part.page_part_key] = page_part.block_contents[locale]
        end

        properties = {}
        if params[:page_slug] == "home"
          properties[:for_sale] = DisplayPropertiesQuery.new().for_sale
          properties[:for_rent] = DisplayPropertiesQuery.new().for_rent
        end

        return render json: {
          page_parts: public_page_parts,
          page: current_page.as_json_for_fe,
          properties: properties
        }
      else
        return render json: {
          page: {}
        }
      end
    end


    def show_search_page
      locale = params[:locale]
      I18n.locale = locale
      # op below is operation
      # Can be either rent or buy
      current_page = Pwb::Page.find_by_slug params[:op]
      # current_page_title = @current_agency.company_name

      if current_page.present?
        public_page_parts = {}
        current_page.page_parts.each do |page_part|
          public_page_parts[page_part.page_part_key] = page_part.block_contents[locale]
        end

        prop_search_results = DisplayPropertiesQuery.new(search_params: params).from_params

        # if params[:page_slug] == "rent"
        #   prop_search_results = DisplayPropertiesQuery.new().for_rent
        # else
        #   prop_search_results = DisplayPropertiesQuery.new().for_sale
        # end
        # properties_for_rent = DisplayPropertiesQuery.new().for_rent

        return render json: {
          page_parts: public_page_parts,
          page: current_page.as_json_for_fe,
          prop_search_results: prop_search_results
        }
      else
        return render json: {
          page: {}
        }
      end
    end


    def show_home_page
      locale = params[:locale]
      I18n.locale = locale
      current_page = Pwb::Page.find_by_slug "home"
      # current_page_title = @current_agency.company_name

      if current_page.present?
        # if current_page.page_title.present?
        #   current_page_title = current_page.page_title + ' - ' + @current_agency.company_name.to_s
        # end
        public_page_parts = {}
        current_page.page_parts.each do |page_part|
          public_page_parts[page_part.page_part_key] = page_part.block_contents[locale]
        end

        properties_for_sale = DisplayPropertiesQuery.new().for_sale
        properties_for_rent = DisplayPropertiesQuery.new().for_rent

        return render json: {
          page_parts: public_page_parts,
          page: current_page.as_json_for_fe,
          properties: {
            for_sale: properties_for_sale,
            for_rent: properties_for_rent
          }
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
