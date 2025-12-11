require_dependency 'pwb/application_controller'

module Pwb
  class ContactUsController < ApplicationController
    before_action :header_image_url


    def index
      # below was for google map rendering via paloma:
      # js current_agency_primary_address: @current_agency.primary_address
      # js show_contact_map: @current_agency.show_contact_map
      # could explicitly set function for Paloma to use like so:
      # js "Pwb/Sections#contact_us"
      # @enquiry = Message.new


      # @content_to_show = []
      @page = @current_website.pages.find_by_slug "contact-us"
      @page_title = @current_agency.company_name

      if @page.present?
        if @page.page_title.present?
          @page_title = @page.page_title + ' - ' + @current_agency.company_name.to_s
        end
        # @page.ordered_visible_page_contents.each do |page_content|
        #   @content_to_show.push page_content.get_html_or_page_part_key
        # end
      end

      # @page_title = I18n.t("contactUs")
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

      StructuredLogger.info('[ContactForm] Processing submission',
        website_id: @current_website&.id,
        email: params.dig(:contact, :email),
        subject: params.dig(:contact, :subject),
        origin_ip: request.ip
      )

      @contact = @current_website.contacts.find_or_initialize_by(primary_email: params[:contact][:email])
      @contact.attributes = {
        primary_phone_number: params[:contact][:tel],
        first_name: params[:contact][:name]
      }

      @enquiry = Message.new(
        {
          website: @current_website,
          title: params[:contact][:subject],
          content: params[:contact][:message],
          locale: params[:contact][:locale],
          url: request.referer,
          host: request.host,
          origin_ip: request.ip,
          user_agent: request.user_agent,
          delivery_email: @current_agency.email_for_general_contact_form
        }
      )

      unless @enquiry.save && @contact.save
        @error_messages += @contact.errors.full_messages
        @error_messages += @enquiry.errors.full_messages
        StructuredLogger.warn('[ContactForm] Validation failed',
          website_id: @current_website&.id,
          email: params.dig(:contact, :email),
          contact_errors: @contact.errors.full_messages,
          enquiry_errors: @enquiry.errors.full_messages
        )
        return render "pwb/ajax/contact_us_errors"
      end

      unless @current_agency.email_for_general_contact_form.present?
        @enquiry.delivery_email = "no_delivery_email@propertywebbuilder.com"
        StructuredLogger.warn('[ContactForm] No delivery email configured',
          website_id: @current_website&.id,
          agency_id: @current_agency&.id
        )
      end

      @enquiry.contact = @contact
      @enquiry.save

      # Async email delivery via Solid Queue
      EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_later

      # Send push notification via ntfy (async)
      if @current_website.ntfy_enabled?
        NtfyNotificationJob.perform_later(@current_website.id, :inquiry, @enquiry.id)
      end

      StructuredLogger.info('[ContactForm] Submission successful',
        website_id: @current_website&.id,
        contact_id: @contact.id,
        message_id: @enquiry.id,
        delivery_email: @enquiry.delivery_email
      )

      @flash = I18n.t "contact.success"
      return render "pwb/ajax/contact_us_success", layout: false
    rescue StandardError => e
      StructuredLogger.exception(e, '[ContactForm] Unexpected error during submission',
        website_id: @current_website&.id,
        email: params.dig(:contact, :email),
        origin_ip: request.ip
      )
      @error_messages = [I18n.t("contact.error"), e.message]
      return render "pwb/ajax/contact_us_errors", layout: false
    end


    private

    def header_image_url
      # lc_content = Content.where(tag: 'landing-carousel')[0]
      lc_photo = ContentPhoto.find_by_block_key "landing_img"
      # used by berlin theme
      @header_image_url = lc_photo.present? ? lc_photo.optimized_image_url : nil
    end
  end
end
