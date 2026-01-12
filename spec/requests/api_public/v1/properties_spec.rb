# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::Properties", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website, subdomain: 'properties-test') }
  let!(:realty_asset) { FactoryBot.create(:pwb_realty_asset, website: website, created_at: 2.days.ago) }
  let!(:sale_listing) { FactoryBot.create(:pwb_sale_listing, :visible, realty_asset: realty_asset) }
  let!(:cheapest_asset) { FactoryBot.create(:pwb_realty_asset, website: website, created_at: 3.days.ago) }
  let!(:cheapest_sale_listing) do
    FactoryBot.create(:pwb_sale_listing, :visible, realty_asset: cheapest_asset, price_sale_current_cents: 100_000_00)
  end
  let!(:priciest_asset) { FactoryBot.create(:pwb_realty_asset, website: website, created_at: 1.day.ago) }
  let!(:priciest_sale_listing) do
    FactoryBot.create(:pwb_sale_listing, :visible, realty_asset: priciest_asset, price_sale_current_cents: 500_000_00)
  end

  before do
    # Refresh the materialized view so properties are visible
    Pwb::ListedProperty.refresh(concurrently: false)
  end

  describe "GET /api_public/v1/properties/:id" do
    it "returns the property" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties/#{realty_asset.id}"
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["id"]).to eq(realty_asset.id)
    end

    it "returns the property by slug" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties/#{realty_asset.slug}"
      expect(response).to have_http_status(200)
      json = response.parsed_body
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

    it "returns data in correct structure with meta" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale" }
      json = response.parsed_body
      expect(json).to have_key("data")
      expect(json).to have_key("meta")
      expect(json["meta"]).to have_key("total")
      expect(json["meta"]).to have_key("page")
      expect(json["meta"]).to have_key("per_page")
      expect(json["meta"]).to have_key("total_pages")
    end

    it "returns map_markers array" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale" }
      json = response.parsed_body
      expect(json).to have_key("map_markers")
      expect(json["map_markers"]).to be_an(Array)
    end

    it "supports pagination parameters" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale", page: 1, per_page: 5 }
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["meta"]["page"]).to eq(1)
      expect(json["meta"]["per_page"]).to eq(5)
    end

    it "supports highlighted filter" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale", highlighted: "true" }
      expect(response).to have_http_status(200)
    end

    it "supports limit parameter" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale", limit: 3 }
      expect(response).to have_http_status(200)
    end

    it "respects locale parameter" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale", locale: "es" }
      expect(response).to have_http_status(200)
    end

    it "supports sort_by price_asc" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale", sort_by: "price_asc" }
      json = response.parsed_body
      prices = json["data"].map { |property| property["price_sale_current_cents"] }
      expect(prices).to eq(prices.sort)
    end

    it "supports sort_by newest" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale", sort_by: "newest" }
      json = response.parsed_body
      ordered_ids = json["data"].map { |property| property["id"] }
      expect(ordered_ids.first).to eq(priciest_asset.id)
    end
  end
end
