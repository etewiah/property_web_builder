# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::SiteDetails", type: :request do
  let!(:website) do
    FactoryBot.create(:pwb_website,
      company_display_name: "My Real Estate",
      default_client_locale: "en",
      supported_locales: %w[en es],
      default_meta_description: "Best properties in town"
    )
  end

  before(:each) do
    allow(Pwb::Current).to receive(:website).and_return(website)
    host! "example.com"
  end

  describe "GET /api_public/v1/:locale/site_details" do
    it "returns site details with new structure" do
      get "/api_public/v1/en/site_details"
      
      expect(response).to have_http_status(200)
      json = response.parsed_body
      
      # Requester info
      expect(json["requester_locale"]).to eq("en")
      expect(json["requester_hostname"]).to include("example.com")
      
      # Caching
      expect(json["cache_control"]).to eq("public, max-age=3600")
      expect(json["etag"]).to be_present
      expect(json["last_modified"]).to be_present
      
      # SEO Defaults
      expect(json["title"]).to eq("My Real Estate") # Fallback to company name
      expect(json["meta_description"]).to eq("Best properties in town")
      expect(json).to have_key("meta_keywords")
    end

    it "includes Open Graph defaults" do
      get "/api_public/v1/en/site_details"
      json = response.parsed_body
      og = json["og"]

      expect(og).to be_present
      expect(og["og:title"]).to eq("My Real Estate")
      expect(og["og:description"]).to eq("Best properties in town")
      expect(og["og:type"]).to eq("website")
      expect(og["og:site_name"]).to eq("My Real Estate")
      expect(og["og:url"]).to eq("http://example.com/")
    end
    
    it "includes Twitter Card defaults" do
      get "/api_public/v1/en/site_details"
      json = response.parsed_body
      twitter = json["twitter"]

      expect(twitter["twitter:card"]).to eq("summary_large_image")
      expect(twitter["twitter:title"]).to eq("My Real Estate")
    end

    it "includes JSON-LD WebSite schema" do
      get "/api_public/v1/en/site_details"
      json = response.parsed_body
      json_ld = json["json_ld"]
      
      expect(json_ld["@type"]).to eq("WebSite")
      expect(json_ld["name"]).to eq("My Real Estate")
      expect(json_ld["url"]).to eq("http://example.com/")
      expect(json_ld["inLanguage"]).to eq("en")
      expect(json_ld["publisher"]["@type"]).to eq("Organization")
    end

    it "adjusts URLs for non-default locale" do
      get "/api_public/v1/es/site_details"
      json = response.parsed_body
      
      expect(json["requester_locale"]).to eq("es")
      expect(json["og"]["og:url"]).to eq("http://example.com/es/")
      expect(json["json_ld"]["url"]).to eq("http://example.com/es/")
      expect(json["json_ld"]["inLanguage"]).to eq("es")
    end

    it "includes analytics keys" do
      website.define_singleton_method(:ga4_measurement_id) { "G-123456" }
      
      get "/api_public/v1/en/site_details"
      json = response.parsed_body
      
      expect(json["analytics"]["ga4_id"]).to eq("G-123456")
    end
  end
end
