# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::SearchConfig", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website, subdomain: 'search-config-test') }
  let!(:realty_asset) { FactoryBot.create(:pwb_realty_asset, website: website, prop_type_key: 'apartment') }
  let!(:sale_listing) { FactoryBot.create(:pwb_sale_listing, :visible, realty_asset: realty_asset) }

  before do
    host! 'search-config-test.example.com'
    # Refresh the materialized view so properties are visible
    Pwb::ListedProperty.refresh(concurrently: false)
  end

  describe "GET /api_public/v1/search/config" do
    it "returns successful response" do
      get "/api_public/v1/search/config"
      expect(response).to have_http_status(200)
    end

    it "returns property_types array" do
      get "/api_public/v1/search/config"
      json = response.parsed_body
      expect(json).to have_key("property_types")
      expect(json["property_types"]).to be_an(Array)
    end

    it "returns price_options with sale and rent" do
      get "/api_public/v1/search/config"
      json = response.parsed_body
      expect(json).to have_key("price_options")
      expect(json["price_options"]).to have_key("sale")
      expect(json["price_options"]).to have_key("rent")
    end

    it "returns bedrooms and bathrooms arrays" do
      get "/api_public/v1/search/config"
      json = response.parsed_body
      expect(json["bedrooms"]).to be_an(Array)
      expect(json["bathrooms"]).to be_an(Array)
    end

    it "returns sort_options" do
      get "/api_public/v1/search/config"
      json = response.parsed_body
      expect(json["sort_options"]).to be_an(Array)
      expect(json["sort_options"].first).to have_key("value")
      expect(json["sort_options"].first).to have_key("label")
    end

    it "respects locale parameter" do
      get "/api_public/v1/search/config", params: { locale: "es" }
      expect(response).to have_http_status(200)
    end
  end
end
