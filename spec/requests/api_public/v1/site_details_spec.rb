# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::SiteDetails", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website) }

  before(:each) do
    Pwb::Current.reset
  end

  describe "GET /api_public/v1/site_details" do
    it "returns site details" do
      get "/api_public/v1/site_details", params: { locale: "en" }
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json).to be_present
    end

    it "includes footer_data object" do
      get "/api_public/v1/site_details", params: { locale: "en" }
      json = response.parsed_body

      expect(json).to have_key("footer_data")
      expect(json["footer_data"]).to have_key("page_parts")
      expect(json["footer_data"]).to have_key("whitelabel")
      expect(json["footer_data"]).to have_key("admin_url")
    end

    it "returns whitelabel configuration with defaults in footer_data" do
      get "/api_public/v1/site_details", params: { locale: "en" }
      json = response.parsed_body

      expect(json["footer_data"]["whitelabel"]).to include(
        "show_powered_by" => true,
        "powered_by_url" => "https://www.propertywebbuilder.com"
      )
    end

    it "returns admin_url in footer_data" do
      get "/api_public/v1/site_details", params: { locale: "en" }
      json = response.parsed_body

      expect(json["footer_data"]["admin_url"]).to eq("/pwb_login")
    end

    it "returns empty page_parts in footer_data when none exist" do
      get "/api_public/v1/site_details", params: { locale: "en" }
      json = response.parsed_body

      expect(json["footer_data"]["page_parts"]).to eq({})
    end
  end
end

RSpec.describe Pwb::Website, "footer data methods", type: :model do
  let(:website) { FactoryBot.create(:pwb_website) }

  describe "#footer_data" do
    it "returns nested object with page_parts, whitelabel, and admin_url" do
      expect(website.footer_data).to have_key("page_parts")
      expect(website.footer_data).to have_key("whitelabel")
      expect(website.footer_data).to have_key("admin_url")
    end
  end

  describe "#whitelabel_for_api" do
    it "returns default values when whitelabel_config is nil" do
      expect(website.whitelabel_for_api).to eq({
        "show_powered_by" => true,
        "powered_by_url" => "https://www.propertywebbuilder.com"
      })
    end

    it "respects custom whitelabel_config" do
      website.update!(whitelabel_config: {
        "show_powered_by" => false,
        "powered_by_url" => "https://custom.com"
      })

      expect(website.whitelabel_for_api).to eq({
        "show_powered_by" => false,
        "powered_by_url" => "https://custom.com"
      })
    end
  end

  describe "#admin_url" do
    it "returns /pwb_login" do
      expect(website.admin_url).to eq("/pwb_login")
    end
  end

  describe "#footer_page_parts" do
    it "returns empty hash when no footer content exists" do
      expect(website.footer_page_parts).to eq({})
    end
  end

  describe "#full_agency_address" do
    it "returns nil when no agency" do
      expect(website.full_agency_address).to be_nil
    end
  end

  describe "#contact_info" do
    it "returns empty hash when no agency" do
      website.agency&.destroy
      website.reload
      expect(website.contact_info).to eq({})
    end
  end
end
