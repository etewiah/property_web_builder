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

    it "accepts locale-prefixed path" do
      host! 'properties-test.example.com'
      get "/api_public/v1/en/properties", params: { sale_or_rental: "sale" }
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json).to have_key("data")
      expect(response.headers["Vary"]).to include("Accept-Language")
      expect(response.headers["Vary"]).to include("X-Website-Slug")
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

    it "supports sort_by price_low_high (alias for price_asc)" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale", sort_by: "price_low_high" }
      json = response.parsed_body
      prices = json["data"].map { |property| property["price_sale_current_cents"] }
      expect(prices).to eq(prices.sort)
    end

    it "supports sort_by price_high_low (alias for price_desc)" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale", sort_by: "price_high_low" }
      json = response.parsed_body
      prices = json["data"].map { |property| property["price_sale_current_cents"] }
      expect(prices).to eq(prices.sort.reverse)
    end

    context "with varying bedroom counts" do
      let!(:few_bed_asset) { FactoryBot.create(:pwb_realty_asset, website: website, count_bedrooms: 1) }
      let!(:few_bed_listing) { FactoryBot.create(:pwb_sale_listing, :visible, realty_asset: few_bed_asset) }
      let!(:many_bed_asset) { FactoryBot.create(:pwb_realty_asset, website: website, count_bedrooms: 5) }
      let!(:many_bed_listing) { FactoryBot.create(:pwb_sale_listing, :visible, realty_asset: many_bed_asset) }

      before { Pwb::ListedProperty.refresh(concurrently: false) }

      it "supports sort_by beds_high_low" do
        host! 'properties-test.example.com'
        get "/api_public/v1/properties", params: { sale_or_rental: "sale", sort_by: "beds_high_low" }
        json = response.parsed_body
        bedrooms = json["data"].map { |property| property["count_bedrooms"] }
        expect(bedrooms).to eq(bedrooms.sort.reverse)
      end
    end

    it "includes constructed_area in property response" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale" }
      json = response.parsed_body
      property = json["data"].first
      expect(property).to have_key("constructed_area")
    end

    it "includes area_unit in property response" do
      host! 'properties-test.example.com'
      get "/api_public/v1/properties", params: { sale_or_rental: "sale" }
      json = response.parsed_body
      property = json["data"].first
      expect(property).to have_key("area_unit")
      expect(property["area_unit"]).to be_in(%w[sqmt sqft])
    end

    context "with group_by=sale_or_rental" do
      let!(:rental_asset) { FactoryBot.create(:pwb_realty_asset, website: website) }
      let!(:rental_listing) { FactoryBot.create(:pwb_rental_listing, :visible, realty_asset: rental_asset) }

      before do
        Pwb::ListedProperty.refresh(concurrently: false)
      end

      it "returns properties grouped by sale and rental" do
        host! 'properties-test.example.com'
        get "/api_public/v1/properties", params: { group_by: "sale_or_rental" }
        expect(response).to have_http_status(200)
        json = response.parsed_body
        expect(json).to have_key("sale")
        expect(json).to have_key("rental")
        expect(json["sale"]).to have_key("properties")
        expect(json["sale"]).to have_key("meta")
        expect(json["rental"]).to have_key("properties")
        expect(json["rental"]).to have_key("meta")
      end

      it "respects per_group parameter" do
        host! 'properties-test.example.com'
        get "/api_public/v1/properties", params: { group_by: "sale_or_rental", per_group: 2 }
        json = response.parsed_body
        expect(json["sale"]["properties"].length).to be <= 2
        expect(json["rental"]["properties"].length).to be <= 2
        expect(json["sale"]["meta"]["per_group"]).to eq(2)
      end

      it "supports featured filter with grouped results" do
        # Create a highlighted listing using the trait
        highlighted_asset = FactoryBot.create(:pwb_realty_asset, website: website)
        FactoryBot.create(:pwb_sale_listing, :visible, :highlighted, realty_asset: highlighted_asset)
        Pwb::ListedProperty.refresh(concurrently: false)

        host! 'properties-test.example.com'
        get "/api_public/v1/properties", params: { group_by: "sale_or_rental", featured: "true" }
        expect(response).to have_http_status(200)
      end
    end
  end
end
