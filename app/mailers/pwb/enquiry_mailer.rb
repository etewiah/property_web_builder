# frozen_string_literal: true

module Pwb
  class EnquiryMailer < Pwb::ApplicationMailer
    # Callbacks to track delivery success/failure
    after_deliver :mark_delivery_success
    rescue_from StandardError, with: :handle_delivery_error

    # General contact form enquiry
    # Sent to the agency's general contact email
    def general_enquiry_targeting_agency(contact, message)
      @contact = contact
      @message = message
      @title = message.title.presence || I18n.t("mailers.general_enquiry_targeting_agency.title")

      # Try to use custom template if available
      if custom_template_available?("enquiry.general")
        send_with_custom_template(
          "enquiry.general",
          to: message.delivery_email,
          reply_to: message.origin_email,
          variables: general_enquiry_variables
        )
      else
        # Fall back to existing ERB template
        mail(
          to: message.delivery_email,
          reply_to: message.origin_email,
          subject: @title,
          template_path: "pwb/mailers",
          template_name: "general_enquiry_targeting_agency"
        )
      end
    end

    # Property-specific enquiry
    # Sent to the agency's property contact email
    def property_enquiry_targeting_agency(contact, message, property)
      @contact = contact
      @message = message
      @property = property
      @title = message.title.presence || I18n.t("mailers.property_enquiry_targeting_agency.title")

      # Try to use custom template if available
      if custom_template_available?("enquiry.property")
        send_with_custom_template(
          "enquiry.property",
          to: message.delivery_email,
          reply_to: message.origin_email,
          variables: property_enquiry_variables
        )
      else
        # Fall back to existing ERB template
        mail(
          to: message.delivery_email,
          reply_to: message.origin_email,
          subject: @title,
          template_path: "pwb/mailers",
          template_name: "property_enquiry_targeting_agency"
        )
      end
    end

    private

    # Check if a custom template exists and is active for the current website
    def custom_template_available?(template_key)
      return false unless current_website

      renderer = EmailTemplateRenderer.new(website: current_website, template_key: template_key)
      renderer.custom_template_exists?
    end

    # Send email using custom Liquid template
    def send_with_custom_template(template_key, to:, reply_to:, variables:)
      renderer = EmailTemplateRenderer.new(website: current_website, template_key: template_key)
      rendered = renderer.render(variables)

      mail(
        to: to,
        reply_to: reply_to,
        subject: rendered[:subject]
      ) do |format|
        format.html { render html: rendered[:body_html].html_safe }
        format.text { render plain: rendered[:body_text] } if rendered[:body_text].present?
      end
    end

    # Get current website from message or Current context
    def current_website
      @message&.website || Pwb::Current.website
    end

    # Variables for general enquiry template
    def general_enquiry_variables
      {
        "visitor_name" => @contact&.first_name || "Visitor",
        "visitor_email" => @contact&.primary_email || @message.origin_email,
        "visitor_phone" => @contact&.primary_phone_number,
        "message" => @message.content,
        "website_name" => current_website&.company_display_name || "Our Website"
      }
    end

    # Variables for property enquiry template
    def property_enquiry_variables
      general_enquiry_variables.merge(
        "property_title" => @property&.title,
        "property_reference" => @property&.reference,
        "property_url" => property_url
      )
    end

    # Generate URL for property (if available)
    def property_url
      return nil unless @property && current_website

      # Build URL based on property type
      if @property.respond_to?(:for_sale?) && @property.for_sale?
        Rails.application.routes.url_helpers.prop_show_for_sale_url(
          @property.id,
          @property.url_friendly_title,
          host: current_website.primary_url || "localhost"
        )
      elsif @property.respond_to?(:for_rent?) && @property.for_rent?
        Rails.application.routes.url_helpers.prop_show_for_rent_url(
          @property.id,
          @property.url_friendly_title,
          host: current_website.primary_url || "localhost"
        )
      end
    rescue StandardError
      nil
    end

    # Update message record to mark successful delivery
    def mark_delivery_success
      return unless @message

      @message.update(
        delivery_success: true,
        delivered_at: Time.current
      )
      Rails.logger.info "[EnquiryMailer] Successfully delivered email for message ##{@message.id}"
    end

    # Handle delivery errors and record them on the message
    def handle_delivery_error(exception)
      if @message
        @message.update(
          delivery_success: false,
          delivery_error: "#{exception.class}: #{exception.message}"
        )
        Rails.logger.error "[EnquiryMailer] Failed to deliver email for message ##{@message.id}: #{exception.message}"
      else
        Rails.logger.error "[EnquiryMailer] Failed to deliver email: #{exception.message}"
      end

      # Re-raise the exception so the job can be retried
      raise exception
    end
  end
end
