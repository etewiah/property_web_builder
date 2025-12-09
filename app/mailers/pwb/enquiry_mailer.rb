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

      # Use enquirer's email as reply-to, but send from our domain for deliverability
      mail(
        to: message.delivery_email,
        reply_to: message.origin_email,
        subject: @title,
        template_path: "pwb/mailers",
        template_name: "general_enquiry_targeting_agency"
      )
    end

    # Property-specific enquiry
    # Sent to the agency's property contact email
    def property_enquiry_targeting_agency(contact, message, property)
      @contact = contact
      @message = message
      @property = property
      @title = message.title.presence || I18n.t("mailers.property_enquiry_targeting_agency.title")

      # Use enquirer's email as reply-to, but send from our domain for deliverability
      mail(
        to: message.delivery_email,
        reply_to: message.origin_email,
        subject: @title,
        template_path: "pwb/mailers",
        template_name: "property_enquiry_targeting_agency"
      )
    end

    private

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
