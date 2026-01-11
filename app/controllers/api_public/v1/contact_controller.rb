# frozen_string_literal: true

module ApiPublic
  module V1
    # ContactController handles general (non-property) contact form submissions
    # For property-specific enquiries, use EnquiriesController
    class ContactController < BaseController
      # POST /api_public/v1/contact
      def create
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale
        website = Pwb::Current.website

        # Find or create contact
        contact = website.contacts.find_or_initialize_by(primary_email: contact_params[:email])
        contact.assign_attributes(
          first_name: contact_params[:name],
          primary_phone_number: contact_params[:phone]
        )

        # Create the message
        title = contact_params[:subject].presence || I18n.t("contact.general_enquiry", default: "General Enquiry")
        message = Pwb::Message.new(
          website: website,
          title: title,
          content: contact_params[:message],
          locale: locale,
          url: request.referer,
          host: request.host,
          origin_ip: request.ip,
          origin_email: contact_params[:email],
          user_agent: request.user_agent,
          delivery_email: website.agency&.email_for_contact_form.presence || website.agency&.email_primary
        )

        # Validate and save
        unless message.valid? && contact.valid?
          errors = contact.errors.full_messages + message.errors.full_messages
          return render json: { success: false, errors: errors }, status: :unprocessable_entity
        end

        contact.save!
        message.contact = contact
        message.save!

        # Send email notification asynchronously
        delivery_email = website.agency&.email_for_contact_form.presence || website.agency&.email_primary
        if delivery_email.present?
          begin
            ContactMailer.general_enquiry(contact, message).deliver_later if defined?(ContactMailer) && ContactMailer.respond_to?(:general_enquiry)
          rescue StandardError => e
            Rails.logger.warn("[Contact API] Email delivery failed: #{e.message}")
          end
        end

        render json: {
          success: true,
          message: I18n.t("contact.success", default: "Thank you for your message. We'll get back to you soon."),
          data: {
            contact_id: contact.id,
            message_id: message.id
          }
        }, status: :created

      rescue StandardError => e
        Rails.logger.error("[API Contact] Error: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
        render json: {
          success: false,
          errors: [I18n.t("contact.error", default: "An error occurred. Please try again.")]
        }, status: :internal_server_error
      end

      private

      def contact_params
        params.require(:contact).permit(:name, :email, :phone, :message, :subject)
      end
    end
  end
end
