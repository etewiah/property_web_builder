module Mutations
  class SubmitListingEnquiry < BaseMutation
    # arguments passed to the `resolve` method
    argument :propertyId, String, required: true
    # argument :url, String, required: true
    argument :contact, GraphQL::Types::JSON, required: true

    # return type from the mutation
    type GraphQL::Types::JSON # Types::LinkType

    def resolve(propertyId: nil, contact: nil)
      current_website = Pwb::Current.website || Pwb::Website.first
      current_agency = current_website&.agency
      success_result = {
        message: "Enquiry submitted successfully",
      }

      error_message = []
      # I18n.locale = params["contact"]["locale"] || I18n.default_locale

      @property = current_website.props.find(propertyId)
      @contact = Pwb::Contact.find_or_initialize_by(primary_email: contact["email"])
      @contact.attributes = {
        primary_phone_number: contact["tel"],
        first_name: contact["name"],
      }

      title = I18n.t "mailers.property_enquiry_targeting_agency.title"
      @enquiry = Pwb::Message.new({
        title: title,
        # content: contact[:message],
        # locale: contact[:locale],
        url: context[:request_url],
        host: context[:request_host],
        origin_ip: context[:request_ip],
        user_agent: context[:request_user_agent],
        delivery_email: current_agency.email_for_property_contact_form,
      })

      unless @enquiry.save && @contact.save
        error_message += @contact.errors.full_messages.to_s
        error_message += @enquiry.errors.full_messages.to_s
        return {
                 result: error_message,
                 client_mutation_id: "0",
               }
      end

      unless current_agency.email_for_property_contact_form.present?
        # in case a delivery email has not been set
        @enquiry.delivery_email = "no_delivery_email@propertywebbuilder.com"
      end

      @enquiry.contact = @contact
      @enquiry.save

      Pwb::EnquiryMailer.property_enquiry_targeting_agency(@contact, @enquiry, @property).deliver
      # @enquiry.save
      return {
               result: "success",
               client_mutation_id: "0",
             }
    rescue => e
      # TODO: - log error to logger....
      error_message = I18n.t("contact.error"), e
      return {
               result: error_message,
               client_mutation_id: "0",
             }
    end
  end
end
