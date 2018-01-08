module Pwb
  # Preview all emails at http://localhost:3000/rails/mailers/pwb/enquiry_mailer
  # after setting:
  #   config.action_mailer.preview_path = Pwb::Engine.root.join('spec/mailers/previews/pwb')
  # in dummy environment.rb
  class EnquiryMailerPreview < ActionMailer::Preview
    # def general_enquiry_targeting_enquirer
    #   @message = Message.new(email: "jd@propertywebbuilder.com")
    #   EnquiryMailer.general_enquiry_targeting_enquirer(Tenant.first, @message)
    # end

    def general_enquiry_targeting_agency
      @message = Message.new(origin_email: "jd@propertywebbuilder.com", delivery_email: "test@test.com")
      @client = Client.new(first_names: "John Doe", phone_number_primary: "22 44", email: "jd@propertywebbuilder.com")
      EnquiryMailer.general_enquiry_targeting_agency(@client, @message)
    end

    def property_enquiry_targeting_agency
      title = I18n.t "mailers.property_enquiry_targeting_agency.title"
      @message = Message.new(origin_email: "jd@propertywebbuilder.com", url: "http://test.com", title: title)
      @property = Prop.last
      @client = Client.new(first_names: "John Doe", phone_number_primary: "22 44", email: "jd@propertywebbuilder.com")
      EnquiryMailer.property_enquiry_targeting_agency(@client, @message, @property)
    end
  end
end
