require "rails_helper"


module Pwb
  RSpec.describe EnquiryMailer, type: :mailer do
    # before(:each) do
    #   ActionMailer::Base.delivery_method = :test
    #   ActionMailer::Base.perform_deliveries = true
    #   ActionMailer::Base.deliveries = []
    #   # @contact = Factory.create(:contact)
    #   # @enquiry = Factory.create(:enquiry)
    #   # EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_now
    # end

    describe 'general enquiry' do
      let(:contact) { Contact.new(first_name: "John Doe", primary_phone_number: "22 44", primary_email: "jd@propertywebbuilder.com") }
      let(:message) { Message.new(origin_email: "jd@propertywebbuilder.com", delivery_email: "test@test.com") }
      let(:mail) { EnquiryMailer.general_enquiry_targeting_agency(contact, message).deliver_now }

      it "sends enquiry successfully" do
        expect(mail.subject).to eq("General enquiry from your website")
        expect(mail.to).to eq(["test@test.com"])
        # From address is our domain for deliverability, enquirer's email is in reply-to
        expect(mail.from).to eq(["noreply@propertywebbuilder.com"])
        expect(mail.reply_to).to eq(["jd@propertywebbuilder.com"])
      end
    end


    describe 'property enquiry' do
      let(:website) { FactoryBot.create(:pwb_website) }
      let(:contact) { Contact.new(first_name: "John Doe", primary_phone_number: "22 44", primary_email: "jd@propertywebbuilder.com") }
      let(:message) { Message.new(origin_email: "jd@propertywebbuilder.com", delivery_email: "test@test.com") }
      let(:prop) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_prop, title: "Charming flat for sale", website: website)
        end
      end

      let(:mail) { EnquiryMailer.property_enquiry_targeting_agency(contact, message, prop).deliver_now }



      it "sends enquiry successfully" do
        expect(mail.subject).to eq("Enquiry regarding a property")
        expect(mail.to).to eq(["test@test.com"])
        # From address is our domain for deliverability, enquirer's email is in reply-to
        expect(mail.from).to eq(["noreply@propertywebbuilder.com"])
        expect(mail.reply_to).to eq(["jd@propertywebbuilder.com"])
      end

      it "renders the body" do
        expect(mail.body.encoded).to include 'Charming flat for sale'
        # mail.body.encoded.should match(edit_password_reset_path(user.password_reset_token))
      end
      # it 'should send an email' do
      #   ActionMailer::Base.deliveries.count.should == 1
      # end
    end

    # after(:each) do
    #   ActionMailer::Base.deliveries.clear
    # end
  end
end
