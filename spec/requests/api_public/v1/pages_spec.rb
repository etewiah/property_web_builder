require 'rails_helper'

RSpec.describe "ApiPublic::V1::Pages", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website, subdomain: "pages-test") }
  let!(:page) { FactoryBot.create(:pwb_page, slug: "about-us", website: website) }

  before(:each) do
    Pwb::Current.reset
    Pwb::Current.website = website
  end

  describe "GET /api_public/v1/pages/:id" do
    it "returns the page" do
      get "/api_public/v1/pages/#{page.id}"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(page.id)
    end

    context "when page does not exist" do
      it "returns a descriptive error message" do
        get "/api_public/v1/pages/99999"
        expect(response).to have_http_status(404)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Page not found")
        expect(json["message"]).to include("No page exists with id '99999'")
        expect(json["code"]).to eq("PAGE_NOT_FOUND")
      end
    end
  end

  describe "GET /api_public/v1/pages/by_slug/:slug" do
    it "returns the page by slug" do
      get "/api_public/v1/pages/by_slug/about-us"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["slug"]).to eq("about-us")
    end

    context "when page does not exist" do
      it "returns a descriptive error message with available pages" do
        get "/api_public/v1/pages/by_slug/nonexistent-page"
        expect(response).to have_http_status(404)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Page not found")
        expect(json["message"]).to include("No page exists with slug 'nonexistent-page'")
        expect(json["message"]).to include("about-us")
        expect(json["code"]).to eq("PAGE_NOT_FOUND")
      end
    end
  end

  describe "website not provisioned errors" do
    context "when website has no pages" do
      before do
        # Remove all pages from the website to simulate unprovisioned state
        website.pages.destroy_all
      end

      it "returns website not provisioned error for show action" do
        get "/api_public/v1/pages/1"
        expect(response).to have_http_status(404)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Website not provisioned")
        expect(json["message"]).to include("has not been provisioned")
        expect(json["code"]).to eq("WEBSITE_NOT_PROVISIONED")
      end

      it "returns website not provisioned error for show_by_slug action" do
        get "/api_public/v1/pages/by_slug/home"
        expect(response).to have_http_status(404)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Website not provisioned")
        expect(json["message"]).to include("has not been provisioned")
        expect(json["message"]).to include("setup/seeding process")
        expect(json["code"]).to eq("WEBSITE_NOT_PROVISIONED")
      end
    end
  end
end
