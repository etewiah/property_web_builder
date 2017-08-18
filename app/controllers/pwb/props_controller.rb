require_dependency "pwb/application_controller"

module Pwb
  class PropsController < ApplicationController
    def show_for_rent
      @carousel_speed = 3000
      # @inmo_template = "broad"
      @property_details = Prop.find_by_id(params[:id])
      # gon.property_details =@property_details
      @operation_type = "for_rent"
      @operation_type_key = @operation_type.camelize(:lower)
      @map_markers = []
      if @property_details && @property_details.visible && @property_details.for_rent
        set_map_marker
        # below lets me know what prices to display
        @show_vacational_rental = @property_details.for_rent_short_term

        js property_details: @property_details
        js 'Pwb/Props#show'
        # page_title gets picked up automatically by meta-tags gem
        @page_title = @property_details.title
        @page_description = @property_details.description
        # @page_keywords    = 'Site, Login, Members'
        return render "/pwb/props/show"
      else
        return render "not_found"
      end
    end

    def show_for_sale
      @carousel_speed = 3000
      # @inmo_template = "broad"
      @operation_type = "for_sale"
      @operation_type_key = @operation_type.camelize(:lower)
      @property_details = Prop.find_by_id(params[:id])
      @map_markers = []

      if @property_details && @property_details.visible && @property_details.for_sale
        set_map_marker
        # gon.property_details =@property_details
        js property_details: @property_details
        js 'Pwb/Props#show'
        @page_title = @property_details.title
        @page_description = @property_details.description
        # @page_keywords    = 'Site, Login, Members'
        return render "/pwb/props/show"
      else
        return render "not_found"
      end
    end

    def request_property_info_ajax
      @error_messages = []
      I18n.locale = params["contact"]["locale"] || I18n.default_locale
      # have a hidden field in form to pass in above
      # if I didn't I could end up with the wrong locale
      # @enquiry = Message.new(params[:contact])
      @property = Prop.find(params[:contact][:property_id])
      @client = Client.find_or_initialize_by(email: params[:contact][:email])
      @client.attributes = {
        phone_number_primary: params[:contact][:tel],
        first_names: params[:contact][:name]
      }

      title = I18n.t "mailers.property_enquiry_targeting_agency.title"
      @enquiry = Message.new({
                               title: title,
                               content: params[:contact][:message],
                               locale: params[:contact][:locale],
                               url: request.referer,
                               host: request.host,
                               origin_ip: request.ip,
                               user_agent: request.user_agent,
                               delivery_email: @current_agency.email_for_property_contact_form
                               # origin_email: params[:contact][:email]
      })

      unless @enquiry.save && @client.save
        @error_messages += @client.errors.full_messages
        @error_messages += @enquiry.errors.full_messages
        return render "pwb/ajax/request_info_errors"
      end

      unless @current_agency.email_for_property_contact_form.present?
        # in case a delivery email has not been set
        @enquiry.delivery_email = "no_delivery_email@propertywebbuilder.com"
      end

      @enquiry.client = @client
      @enquiry.save

      EnquiryMailer.property_enquiry_targeting_agency(@client, @enquiry, @property).deliver
      # @enquiry.delivery_success = true
      @enquiry.save
      @flash = I18n.t "contact.success"
      return render "pwb/ajax/request_info_success", layout: false
    rescue => e

      # TODO: - log error to logger....
      @error_messages = [I18n.t("contact.error"), e]
      return render "pwb/ajax/request_info_errors", layout: false
    end

    private

    def set_map_marker
      if @property_details.show_map
        @map_markers.push(
          {
            id: @property_details.id,
            position: {
              lat: @property_details.latitude,
              lng: @property_details.longitude
            }
          }
        )
      end
    end

  end
end
