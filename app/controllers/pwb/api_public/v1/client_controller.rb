require_dependency "pwb/application_controller"

module Pwb
  class ApiPublic::V1::ClientController < ApplicationApiController

    respond_to :json

    def translations

      locale = params[:locale]
      translations = I18n.t("client", locale: locale, default: {})

      render json: {
        locale => translations
      }
    end


    def client_settings
      # locale = "en"
      locale = params[:locale]
      I18n.locale = locale

      @translations ||= I18n.t("client", locale: locale, default: {})

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
        translations: @translations,
        agency_map_marker: agency_map_marker,
        display_settings: {
          top_nav_links: @top_nav_links,
          footer_links: @footer_links
        },
      }
    end

    private

  end
end
