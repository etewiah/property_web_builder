# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::Links", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website, subdomain: 'links-test') }
  let!(:link) do
    ActsAsTenant.with_tenant(website) do
      FactoryBot.create(:pwb_link, :top_nav, visible: true, website: website)
    end
  end

  describe "GET /api_public/v1/links" do
    it "returns links" do
      host! 'links-test.example.com'
      get "/api_public/v1/links"
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json).to have_key("data")
      expect(json["data"]).to be_an(Array)
    end

    it "filters by placement" do
      host! 'links-test.example.com'
      get "/api_public/v1/links", params: { placement: "top_nav" }
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["data"].first["position"]).to eq("top_nav")
    end

    it "returns all links with position when no filter is provided" do
      # Create footer link
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_link, :footer, visible: true, website: website)
      end

      host! 'links-test.example.com'
      get "/api_public/v1/links"
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["data"].length).to eq(2)
      placements = json["data"].map { |l| l["position"] }
      expect(placements).to include("top_nav", "footer")
    end
  end
end
