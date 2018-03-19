require_dependency "pwb/application_controller"

module Pwb
  class ApiPublic::V1::ClientController < ApplicationApiPublicController

    respond_to :json

    def translations
      locale = params[:locale]
      translations = I18n.t("client", locale: locale, default: {})

      render json: {
        locale => translations
      }
    end


    # TODO - add a cache key for this
    def client_settings
      # locale = "en"
      locale = params[:locale]
      I18n.locale = locale

      @translations = {}
      @translations[:client] = I18n.t("client", locale: locale, default: {})
      @translations[:common] = I18n.t("common", locale: locale, default: {})
      # TODO - prefix all of below with "fe" and use English keys
      @translations[:extras] = I18n.t("extras", locale: locale, default: {})
      @translations[:propertyStates] = I18n.t("propertyStates", locale: locale, default: {})
      @translations[:propertyTypes] = I18n.t("propertyTypes", locale: locale, default: {})
      @translations[:propertyOrigin] = I18n.t("propertyOrigin", locale: locale, default: {})
      @translations[:propertyLabels] = I18n.t("propertyLabels", locale: locale, default: {})


      # TODO - move most of below to models:
      @current_agency ||= Agency.unique_instance
      @current_website = Website.unique_instance
      @footer_page_content ||= @current_website.contents.find_by_page_part_key "footer_content_html"
      @footer_html = ""
      if @footer_page_content.present?
        @footer_html = @footer_page_content.raw
      end


      @search_field_options = get_common_search_inputs

      agency_map_marker = {}
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

      display_settings = @current_website.as_json_for_fe
      # display_settings[:top_nav_links] = @top_nav_links
      # display_settings[:footer_links] = @footer_links
      # display_settings[:footer_html] = @footer_html

      return render json: {
        current_agency: @current_agency.as_json_for_fe,
        # footer_html: @footer_html,
        display_settings: display_settings,
        search_field_options: @search_field_options,
        translations: @translations,
        # agency_map_marker: agency_map_marker,
        # display_settings: {
        #   top_nav_links: @top_nav_links,
        #   footer_links: @footer_links
        # },
      }
    end

    private


    def get_common_search_inputs

      property_types = FieldKey.where(tag: "property-types").visible.pluck("global_key")
      property_states = FieldKey.where(tag: "property-states").visible.pluck("global_key")
      # sale_prices_from = @current_website.sale_price_options_from
      # sale_prices_till = @current_website.sale_price_options_till
      # rent_prices_from = @current_website.rent_price_options_from
      # rent_prices_till = @current_website.rent_price_options_till


      return {
        propertyTypes: property_types,
        propertyStates: property_states,
        # rent_prices_from: rent_prices_from,
        # rent_prices_till: rent_prices_till,
        # sale_prices_from: sale_prices_from,
        # sale_prices_till: sale_prices_till
      }
    end
  end
end
