require 'rails_helper'

RSpec.describe "ApiPublic::V1::SiteDetails", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website) }

  before(:each) do
    Pwb::Current.reset
  end

  describe "GET /api_public/v1/site_details" do
    it "returns site details" do
      get "/api_public/v1/site_details", params: { locale: "en" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json).to be_present
    end
  end
end
