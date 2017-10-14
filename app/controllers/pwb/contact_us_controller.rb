require_dependency 'pwb/application_controller'

module Pwb
  class ContactUsController < ApplicationController
    before_action :header_image


    def index
      # below was for google map rendering via paloma:
      # js current_agency_primary_address: @current_agency.primary_address
      # js show_contact_map: @current_agency.show_contact_map
      # could explicitly set function for Paloma to use like so:
      # js "Pwb/Sections#contact_us"
      # @enquiry = Message.new


      @content_to_show = []
      @page = Pwb::Page.find_by_slug "contact-us"
      if @page.present?
        @page.ordered_visible_page_contents.each do |page_content|
          @content_to_show.push page_content.get_html_or_page_part_key
        end
      end

      @page_title = I18n.t("contactUs")

      @map_markers = []
      if @current_agency.show_contact_map
        @map_markers.push(
          {
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
        )
      end

      render "/pwb/sections/contact_us"
    end

    def contact_us_ajax
      @error_messages = []
      I18n.locale = params["contact"]["locale"] || I18n.default_locale
      # have a hidden field in form to pass in above
      # @enquiry = Message.new(params[:contact])

      @client = Client.find_or_initialize_by(email: params[:contact][:email])
      @client.attributes = {
        phone_number_primary: params[:contact][:tel],
        first_names: params[:contact][:name]
      }

      @enquiry = Message.new(
        {
          title: params[:contact][:subject],
          content: params[:contact][:message],
          locale: params[:contact][:locale],
          url: request.referer,
          host: request.host,
          origin_ip: request.ip,
          user_agent: request.user_agent,
          delivery_email: @current_agency.email_for_general_contact_form
          # origin_email: params[:contact][:email]
        }
      )
      unless @enquiry.save && @client.save
        @error_messages += @client.errors.full_messages
        @error_messages += @enquiry.errors.full_messages
        return render "pwb/ajax/contact_us_errors"
      end

      unless @current_agency.email_for_general_contact_form.present?
        # in case a delivery email has not been set
        @enquiry.delivery_email = "no_delivery_email@propertywebbuilder.com"
      end

      @enquiry.client = @client
      @enquiry.save

      # @enquiry.delivery_email = ""
      EnquiryMailer.general_enquiry_targeting_agency(@client, @enquiry).deliver_now

      # @enquiry.delivery_success = true
      # @enquiry.save

      @flash = I18n.t "contact.success"
      return render "pwb/ajax/contact_us_success", layout: false
    rescue => e
      # TODO: - log error to logger....
      # flash.now[:error] = 'Cannot send message.'
      @error_messages = [I18n.t("contact.error"), e]
      return render "pwb/ajax/contact_us_errors", layout: false
    end


    private

    def header_image
      # used by berlin theme and meta tags
      hi_content = Content.where(tag: 'landing-carousel')[0]
      @header_image = hi_content.present? ? hi_content.default_photo : nil
    end

  end
end
