# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "GraphQL Multi-tenancy", type: :request do
  # Helper to create property with sale listing for GraphQL visibility
  def create_property_with_listing(website:, reference:, price_cents:)
    realty_asset = Pwb::RealtyAsset.create!(
      website: website,
      reference: reference
    )
    Pwb::SaleListing.create!(
      realty_asset: realty_asset,
      reference: reference,
      visible: true,
      archived: false,
      active: true,
      price_sale_current_cents: price_cents,
      price_sale_current_currency: 'EUR'
    )
    # Refresh materialized view after creating listings
    Pwb::ListedProperty.refresh
    realty_asset
  end

  describe "POST /graphql" do
    let!(:website1) { Pwb::Website.create!(slug: "site1", subdomain: "site1") }
    let!(:website2) { Pwb::Website.create!(slug: "site2", subdomain: "site2") }

    # Create properties with proper sale listings for materialized view
    let!(:prop1) { create_property_with_listing(website: website1, reference: "ref1", price_cents: 10_000_000) }
    let!(:prop2) { create_property_with_listing(website: website2, reference: "ref2", price_cents: 20_000_000) }

    it "returns properties for site1" do
      query = <<~GQL
        query {
          searchProperties {
            id
            reference
          }
        }
      GQL

      post "/graphql", params: { query: query }, headers: { "X-Website-Slug" => "site1" }

      json = response.parsed_body
      properties = json["data"]["searchProperties"]

      expect(properties.length).to eq(1)
      expect(properties.first["reference"]).to eq("ref1")
    end

    it "returns properties for site2" do
      query = <<~GQL
        query {
          searchProperties {
            id
            reference
          }
        }
      GQL

      post "/graphql", params: { query: query }, headers: { "X-Website-Slug" => "site2" }

      json = response.parsed_body
      properties = json["data"]["searchProperties"]

      expect(properties.length).to eq(1)
      expect(properties.first["reference"]).to eq("ref2")
    end

    describe "Pages" do
      let!(:page1) { Pwb::Page.create!(website: website1, slug: "home", visible: true) }
      let!(:page2) { Pwb::Page.create!(website: website2, slug: "home", visible: true) }

      it "returns page for site1" do
        query = <<~GQL
          query {
            findPage(slug: "home", locale: "en") {
              id
              slug
            }
          }
        GQL

        post "/graphql", params: { query: query }, headers: { "X-Website-Slug" => "site1" }

        json = response.parsed_body
        page = json["data"]["findPage"]

        expect(page["id"].to_i).to eq(page1.id)
      end

      it "returns page for site2" do
        query = <<~GQL
          query {
            findPage(slug: "home", locale: "en") {
              id
              slug
            }
          }
        GQL

        post "/graphql", params: { query: query }, headers: { "X-Website-Slug" => "site2" }

        json = response.parsed_body
        page = json["data"]["findPage"]

        expect(page["id"].to_i).to eq(page2.id)
      end
    end

    describe "Links" do
      let!(:link1) { Pwb::Link.create!(website: website1, slug: "link1", placement: "top_nav", visible: true) }
      let!(:link2) { Pwb::Link.create!(website: website2, slug: "link2", placement: "top_nav", visible: true) }

      it "returns top nav links for site1" do
        query = <<~GQL
          query {
            getTopNavLinks(locale: "en") {
              slug
            }
          }
        GQL

        post "/graphql", params: { query: query }, headers: { "X-Website-Slug" => "site1" }

        json = response.parsed_body
        links = json["data"]["getTopNavLinks"]

        expect(links.length).to eq(1)
        expect(links.first["slug"]).to eq("link1")
      end
    end

    describe "tenant resolution failures" do
      let(:query) do
        <<~GQL
          query {
            getSiteDetails(locale: "en") {
              slug
            }
          }
        GQL
      end

      it "returns bad request when no tenant can be resolved" do
        host! 'unknown.example.com'

        post "/graphql", params: { query: query }

        expect(response).to have_http_status(:bad_request)
        json = response.parsed_body
        expect(json.dig('errors', 0, 'message')).to include('Website context required')
        expect(json['data']).to eq({})
      end

      it "returns bad request for an invalid website slug header when host is also unknown" do
        host! 'unknown.example.com'

        post "/graphql", params: { query: query }, headers: { 'X-Website-Slug' => 'missing-site' }

        expect(response).to have_http_status(:bad_request)
        json = response.parsed_body
        expect(json.dig('errors', 0, 'message')).to include('Website context required')
      end
    end
  end
end
