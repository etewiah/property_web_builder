require_dependency "pwb/application_controller"

module Pwb
  class ApiPublic::V1::ClientController < ApplicationApiPublicController
    self.page_cache_directory = -> { Rails.root.join("public", request.domain) }
    caches_page :client_settings, :translations
    respond_to :json

    def contact_us
      @error_messages = []
      I18n.locale = params["locale"] || I18n.default_locale
      @current_agency ||= Agency.unique_instance

      @contact = Contact.find_or_initialize_by(primary_email: params[:contact][:email])
      @contact.attributes = {
        primary_phone_number: params[:contact][:tel],
        first_name: params[:contact][:name]
      }

      @enquiry = Message.new(
        {
          title: params[:contact][:subject],
          content: params[:contact][:message],
          locale: I18n.locale,
          url: request.referer,
          host: request.host,
          origin_ip: request.ip,
          user_agent: request.user_agent,
          delivery_email: @current_agency.email_for_general_contact_form
          # origin_email: params[:contact][:email]
        }
      )
      unless @enquiry.save && @contact.save
        @error_messages += @contact.errors.full_messages
        @error_messages += @enquiry.errors.full_messages
        return render json: {
          success: false,
          errors: @error_messages
        }
      end

      unless @current_agency.email_for_general_contact_form.present?
        # in case a delivery email has not been set
        @enquiry.delivery_email = "no_delivery_email@propertywebbuilder.com"
      end

      @enquiry.contact = @contact
      @enquiry.save

      # @enquiry.delivery_email = ""
      EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_now


      # EnquiryMailer.property_enquiry_targeting_agency(@contact, @enquiry, @property).deliver
      # @enquiry.delivery_success = true

      @enquiry.save
      success_message = I18n.t "contact.success"
      return render json: {
        success: true,
        success_message: success_message
      }
    rescue => e
      # TODO: - log error to logger....
      @error_messages = [I18n.t("contact.error"), e]
      return render json: {
        success: false,
        errors: @error_messages
      }
    end


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


      @current_agency ||= Agency.unique_instance
      @current_website ||= Website.unique_instance
      # @footer_page_content ||= @current_website.contents.find_by_page_part_key "footer_content_html"
      # @footer_html = ""
      # if @footer_page_content.present?
      #   @footer_html = @footer_page_content.raw
      # end


      # june 2018: - for pwb-multi-tenant project I now 
      # load client_settings within erb html as a json object
      # - will need to refresh that data via this api endpoint when
      # I change languages though.  Need to make sure the 
      # data I return here stays in synch with the erb json data
      # Right now I no longer need below as I will load it from 
      # search page and it will vary depending on the search config
      @search_field_options = get_common_search_inputs

      # agency_map_marker = {}
      # if @current_agency.show_contact_map
      #   agency_map_marker = {
      #     id: @current_agency.id,
      #     title: @current_agency.display_name,
      #     show_url: "#",
      #     image_url: @current_website.logo_url,
      #     # display_price: @current_agency.contextual_price_with_currency(@operation_type),
      #     position: {
      #       lat: @current_agency.primary_address.latitude,
      #       lng: @current_agency.primary_address.longitude
      #     }
      #   }
      # end

      display_settings = @current_website.as_json_for_fe
      # display_settings[:top_nav_links] = @top_nav_links
      # display_settings[:footer_links] = @footer_links
      # display_settings[:footer_html] = @footer_html

      # below is saved on the client to be used when
      # posting forms
      response.headers['X-CSRF-Token'] = form_authenticity_token.to_s
      response.headers['X-CSRF-Param'] = "authenticity_token"

      admin_url = "#{request.base_url}/#{I18n.locale}/admin"
      current_agency_json = @current_agency.as_json_for_fe
      current_agency_json["admin_url"] = admin_url

      return render json: {
        current_agency: current_agency_json,
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
