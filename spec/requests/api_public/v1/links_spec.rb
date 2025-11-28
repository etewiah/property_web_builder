require 'rails_helper'

RSpec.describe "ApiPublic::V1::Links", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website) }
  let!(:link) { FactoryBot.create(:pwb_link, placement: "top_nav", visible: true, website: website) }

  describe "GET /api_public/v1/links" do
    it "returns links" do
      get "/api_public/v1/links"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
    end

    it "filters by placement" do
      get "/api_public/v1/links", params: { placement: "top_nav" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json.first["placement"]).to eq("top_nav")
    end
  end
end
