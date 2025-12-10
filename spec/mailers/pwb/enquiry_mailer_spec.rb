require "rails_helper"


module Pwb
  RSpec.describe EnquiryMailer, type: :mailer do
    # Get the configured default from address for assertions
    let(:default_from_email) do
      # Extract just the email address from the configured default
      configured = Pwb::ApplicationMailer.default_from_address
      configured.match(/<(.+)>/)&.[](1) || configured
    end

    describe 'general enquiry' do
      let(:contact) { Contact.new(first_name: "John Doe", primary_phone_number: "22 44", primary_email: "jd@example.com") }
      let(:message) { Message.new(origin_email: "jd@example.com", delivery_email: "test@test.com") }
      let(:mail) { EnquiryMailer.general_enquiry_targeting_agency(contact, message).deliver_now }

      it "sends enquiry successfully" do
        expect(mail.subject).to eq("General enquiry from your website")
        expect(mail.to).to eq(["test@test.com"])
        # From address is our domain for deliverability (configured via DEFAULT_FROM_EMAIL)
        expect(mail.from.first).to eq(default_from_email)
        # Enquirer's email is in reply-to so replies go to them
        expect(mail.reply_to).to eq(["jd@example.com"])
      end
    end


    describe 'property enquiry' do
      let(:website) { FactoryBot.create(:pwb_website) }
      let(:contact) { Contact.new(first_name: "John Doe", primary_phone_number: "22 44", primary_email: "jd@example.com") }
      let(:message) { Message.new(origin_email: "jd@example.com", delivery_email: "test@test.com") }
      let(:prop) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_prop, title: "Charming flat for sale", website: website)
        end
      end

      let(:mail) { EnquiryMailer.property_enquiry_targeting_agency(contact, message, prop).deliver_now }



      it "sends enquiry successfully" do
        expect(mail.subject).to eq("Enquiry regarding a property")
        expect(mail.to).to eq(["test@test.com"])
        # From address is our domain for deliverability (configured via DEFAULT_FROM_EMAIL)
        expect(mail.from.first).to eq(default_from_email)
        # Enquirer's email is in reply-to so replies go to them
        expect(mail.reply_to).to eq(["jd@example.com"])
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
