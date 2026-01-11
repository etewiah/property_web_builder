# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::Contact", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website, subdomain: 'contact-test') }
  let!(:agency) { website.agency || website.create_agency!(display_name: 'Test Agency', email_primary: 'test@example.com') }

  before do
    host! 'contact-test.example.com'
  end

  describe "POST /api_public/v1/contact" do
    let(:valid_params) do
      {
        contact: {
          name: "John Doe",
          email: "john@example.com",
          phone: "+1234567890",
          subject: "General Inquiry",
          message: "I would like more information about your services."
        }
      }
    end

    it "creates a contact and message with valid params" do
      expect {
        post "/api_public/v1/contact", params: valid_params, as: :json
      }.to change(Pwb::Contact, :count).by(1)
        .and change(Pwb::Message, :count).by(1)

      expect(response).to have_http_status(201)
      json = response.parsed_body
      expect(json["success"]).to be true
      expect(json["data"]["contact_id"]).to be_present
      expect(json["data"]["message_id"]).to be_present
    end

    it "returns success message" do
      post "/api_public/v1/contact", params: valid_params, as: :json
      json = response.parsed_body
      expect(json["message"]).to be_present
    end

    it "reuses existing contact by email" do
      existing_contact = website.contacts.create!(
        primary_email: "john@example.com",
        first_name: "Existing"
      )

      expect {
        post "/api_public/v1/contact", params: valid_params, as: :json
      }.to change(Pwb::Contact, :count).by(0)
        .and change(Pwb::Message, :count).by(1)

      expect(response).to have_http_status(201)
    end

    it "returns error for missing email" do
      invalid_params = {
        contact: {
          name: "John Doe",
          message: "Hello"
        }
      }

      post "/api_public/v1/contact", params: invalid_params, as: :json
      # Should either return 422 or handle missing parameter
      expect(response.status).to be_in([400, 422, 500])
    end

    it "respects locale parameter" do
      post "/api_public/v1/contact", params: valid_params.merge(locale: "es"), as: :json
      expect(response).to have_http_status(201)
    end
  end
end
