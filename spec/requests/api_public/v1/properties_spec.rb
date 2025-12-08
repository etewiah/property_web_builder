require 'rails_helper'

RSpec.describe "ApiPublic::V1::Properties", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website, subdomain: 'properties-test') }
  let!(:realty_asset) { FactoryBot.create(:pwb_realty_asset, website: website) }
  let!(:sale_listing) { FactoryBot.create(:pwb_sale_listing, :visible, realty_asset: realty_asset) }

  before do
    # Refresh the materialized view so properties are visible
    Pwb::ListedProperty.refresh(concurrently: false)
  end

  describe "GET /api_public/v1/properties/:id" do
    it "returns the property" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties/#{realty_asset.id}"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(realty_asset.id)
    end

    it "returns 404 for non-existent property" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties/00000000-0000-0000-0000-000000000000"
      expect(response).to have_http_status(404)
    end
  end

  describe "GET /api_public/v1/properties" do
    it "returns properties based on search" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale" }
      expect(response).to have_http_status(200)
    end
  end
end
