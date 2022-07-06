module Pwb
  class EnquiryMailer < Pwb::ApplicationMailer
    # default :bcc => "pwb@gmail.com"

    def general_enquiry_targeting_agency(contact, message)
      from = message.origin_email.presence || Pwb::ApplicationMailer.default[:from] || "service@propertywebbuilder.com"
      @contact = contact
      @message = message
      # @title = I18n.t "mailers.general_enquiry_targeting_agency.title"
      # if enquiry.title
      #   @subject = enquiry.title
      # else
      #   @subject = @title
      # end
      @title = message.title.presence || (I18n.t "mailers.general_enquiry_targeting_agency.title")
      mail(to: message.delivery_email,
           from: from,
           subject: @title,
           template_path: "pwb/mailers",
           template_name: "general_enquiry_targeting_agency")
    end

    def property_enquiry_targeting_agency(contact, message, property)
      from = message.origin_email.presence || Pwb::ApplicationMailer.default[:from] || "service@propertywebbuilder.com"
      @contact = contact
      @message = message
      @property = property
      @title = message.title.presence || (I18n.t "mailers.property_enquiry_targeting_agency.title")
      mail(to: message.delivery_email,
           from: from,
           subject: @title,
           template_path: "pwb/mailers",
           template_name: "property_enquiry_targeting_agency")
    end
  end
end
