# frozen_string_literal: true

module ApiPublic
  module V1
    # EnquiriesController handles property enquiry submissions from headless frontends
    # Replicates functionality of Pwb::PropsController#request_property_info_ajax
    class EnquiriesController < BaseController
      # POST /api_public/v1/enquiries
      def create
        locale = params[:locale] || I18n.default_locale
        I18n.locale = locale
        website = Pwb::Current.website

        # Find or create contact
        contact = website.contacts.find_or_initialize_by(primary_email: enquiry_params[:email])
        contact.assign_attributes(
          primary_phone_number: enquiry_params[:phone],
          first_name: enquiry_params[:name]
        )

        # Create the message/enquiry
        title = I18n.t("mailers.property_enquiry_targeting_agency.title")
        message = Pwb::Message.new(
          website: website,
          title: title,
          content: enquiry_params[:message],
          locale: locale,
          url: request.referer,
          host: request.host,
          origin_ip: request.ip,
          origin_email: enquiry_params[:email],
          user_agent: request.user_agent,
          delivery_email: website.agency&.email_for_property_contact_form
        )

        # Validate and save
        unless message.valid? && contact.valid?
          errors = contact.errors.full_messages + message.errors.full_messages
          return render json: { success: false, errors: errors }, status: :unprocessable_entity
        end

        contact.save!
        message.contact = contact
        message.save!

        # Find property if provided (for email context)
        property = nil
        if enquiry_params[:property_id].present?
          property = website.listed_properties.find_by(id: enquiry_params[:property_id]) ||
                     website.listed_properties.find_by(slug: enquiry_params[:property_id])
        end

        # Send email notification asynchronously
        if website.agency&.email_for_property_contact_form.present?
          if property
            EnquiryMailer.property_enquiry_targeting_agency(contact, message, property).deliver_later
          else
            EnquiryMailer.general_enquiry_targeting_agency(contact, message).deliver_later if defined?(EnquiryMailer) && EnquiryMailer.respond_to?(:general_enquiry_targeting_agency)
          end
        end

        render json: {
          success: true,
          message: I18n.t("contact.success"),
          data: {
            contact_id: contact.id,
            message_id: message.id
          }
        }, status: :created

      rescue StandardError => e
        Rails.logger.error("[API Enquiry] Error: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
        render json: {
          success: false,
          errors: [I18n.t("contact.error")]
        }, status: :internal_server_error
      end

      private

      def enquiry_params
        params.require(:enquiry).permit(:name, :email, :phone, :message, :property_id)
      end
    end
  end
end
