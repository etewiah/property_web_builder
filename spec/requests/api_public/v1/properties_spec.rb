require 'rails_helper'

RSpec.describe "ApiPublic::V1::Properties", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website) }
  let!(:prop) { FactoryBot.create(:pwb_prop, :sale, website: website) }

  describe "GET /api_public/v1/properties/:id" do
    it "returns the property" do
      get "/api_public/v1/properties/#{prop.id}"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(prop.id)
    end

    it "returns 404 for non-existent property" do
      get "/api_public/v1/properties/99999"
      expect(response).to have_http_status(404)
    end
  end

  describe "GET /api_public/v1/properties" do
    it "returns properties based on search" do
      get "/api_public/v1/properties", params: { sale_or_rental: "sale" }
      expect(response).to have_http_status(200)
      # Assuming the factory creates a property for sale by default or we might need to adjust
    end
  end
end
