module Pwb
  class EnquiryMailer < ApplicationMailer
    # default :bcc => "pwb@gmail.com"

    def general_enquiry_targeting_agency(client, enquiry)
      @client = client
      @enquiry = enquiry
      @title = I18n.t "mailers.general_enquiry_targeting_agency.title"
      if enquiry.title
        @subject = enquiry.title
      else
        @subject = @title
      end
      mail(to: enquiry.delivery_email,
           subject: @subject,
           template_path: 'pwb/mailers',
           template_name: 'general_enquiry_targeting_agency')
    end

    def property_enquiry_targeting_agency(client, enquiry, property)
      @client = client
      @enquiry = enquiry
      @property = property
      @title = enquiry.title
      mail(to: enquiry.delivery_email,
           subject: @title,
           template_path: 'pwb/mailers',
           template_name: 'property_enquiry_targeting_agency')
    end
  end

end
