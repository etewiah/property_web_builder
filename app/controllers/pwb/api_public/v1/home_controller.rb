require_dependency "pwb/application_controller"

module Pwb
  class ApiPublic::V1::HomeController < ApplicationApiController

    def display_settings
      I18n.locale = "es"

      @current_agency ||= Agency.unique_instance
      @current_website = Website.unique_instance
      footer_page_content = @current_website.ordered_visible_page_contents.find_by_page_part_key "footer_content_html"

      @top_nav_links ||= Pwb::Link.ordered_visible_top_nav.as_json({only: [
               "sort_order",
               "href_class", "link_path_params",
               "slug", "link_path", "visible",
               "link_title", "page_slug"
             ],
             methods: ["target_path"]})
      @footer_links ||= Pwb::Link.ordered_visible_footer.as_json({only: [
               "sort_order",
               "href_class", "link_path_params",
               "slug", "link_path", "visible",
               "link_title", "page_slug"
             ],
             methods: ["target_path"]})

      if @current_agency.show_contact_map
        agency_map_marker = {
            id: @current_agency.id,
            title: @current_agency.display_name,
            show_url: "#",
            image_url: @current_website.logo_url,
            # display_price: @current_agency.contextual_price_with_currency(@operation_type),
            position: {
              lat: @current_agency.primary_address.latitude,
              lng: @current_agency.primary_address.longitude
            }
          }
      end

      return render json: {
        agency_map_marker: agency_map_marker,
        display_settings: {
          top_nav_links: @top_nav_links,
          footer_links: @footer_links
        }
      }
    end

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
