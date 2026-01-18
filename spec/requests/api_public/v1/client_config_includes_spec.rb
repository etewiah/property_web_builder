# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::ClientConfig with includes", type: :request do
  let!(:client_theme) do
    FactoryBot.create(:pwb_client_theme,
                      name: 'test_theme',
                      friendly_name: 'Test Theme',
                      default_config: { 'primary_color' => '#FF0000' })
  end
  let!(:website) do
    FactoryBot.create(:pwb_website,
                      subdomain: 'client-config-test',
                      rendering_mode: 'client',
                      client_theme_name: 'test_theme')
  end
  let!(:top_nav_link) do
    ActsAsTenant.with_tenant(website) do
      FactoryBot.create(:pwb_link, :top_nav, visible: true, website: website)
    end
  end
  let!(:footer_link) do
    ActsAsTenant.with_tenant(website) do
      FactoryBot.create(:pwb_link, :footer, visible: true, website: website)
    end
  end

  describe "GET /api_public/v1/client-config" do
    it "returns basic config without includes" do
      host! 'client-config-test.example.com'
      get "/api_public/v1/client-config"
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["data"]).to have_key("rendering_mode")
      expect(json["data"]).to have_key("theme")
      expect(json["data"]).not_to have_key("links")
      expect(json["data"]).not_to have_key("site_details")
    end

    context "with include=links" do
      it "includes links with placement" do
        host! 'client-config-test.example.com'
        get "/api_public/v1/client-config", params: { include: "links" }
        expect(response).to have_http_status(200)
        json = response.parsed_body
        expect(json["data"]).to have_key("links")
        expect(json["data"]["links"]).to be_an(Array)
        # Links should include placement field
        if json["data"]["links"].any?
          expect(json["data"]["links"].first).to have_key("position")
        end
      end
    end

    context "with include=site_details" do
      it "includes site details" do
        host! 'client-config-test.example.com'
        get "/api_public/v1/client-config", params: { include: "site_details" }
        expect(response).to have_http_status(200)
        json = response.parsed_body
        expect(json["data"]).to have_key("site_details")
      end
    end

    context "with include=translations" do
      it "includes translations for default locale" do
        host! 'client-config-test.example.com'
        get "/api_public/v1/client-config", params: { include: "translations" }
        expect(response).to have_http_status(200)
        json = response.parsed_body
        expect(json["data"]).to have_key("translations")
      end

      it "includes translations for specified locale" do
        host! 'client-config-test.example.com'
        get "/api_public/v1/client-config", params: { include: "translations", locale: "es" }
        expect(response).to have_http_status(200)
        json = response.parsed_body
        expect(json["data"]).to have_key("translations")
      end
    end

    context "with multiple includes" do
      it "includes all requested data blocks" do
        host! 'client-config-test.example.com'
        get "/api_public/v1/client-config", params: { include: "links,site_details,translations" }
        expect(response).to have_http_status(200)
        json = response.parsed_body
        expect(json["data"]).to have_key("links")
        expect(json["data"]).to have_key("site_details")
        expect(json["data"]).to have_key("translations")
      end
    end

    context "with include=featured_properties" do
      let!(:realty_asset) { FactoryBot.create(:pwb_realty_asset, website: website) }
      let!(:sale_listing) { FactoryBot.create(:pwb_sale_listing, :visible, :highlighted, realty_asset: realty_asset) }

      before do
        Pwb::ListedProperty.refresh(concurrently: false)
      end

      it "includes featured properties grouped by sale/rental" do
        host! 'client-config-test.example.com'
        get "/api_public/v1/client-config", params: { include: "featured_properties" }
        expect(response).to have_http_status(200)
        json = response.parsed_body
        expect(json["data"]).to have_key("featured_properties")
        expect(json["data"]["featured_properties"]).to have_key("sale")
        expect(json["data"]["featured_properties"]).to have_key("rental")
      end
    end

    it "sets Vary header for tenant isolation" do
      host! 'client-config-test.example.com'
      get "/api_public/v1/client-config"
      expect(response.headers["Vary"]).to include("X-Website-Slug")
    end
  end
end
