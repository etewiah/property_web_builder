require 'rails_helper'

RSpec.describe "ApiPublic::V1::Pages", type: :request do
  let!(:website) { Pwb::Website.unique_instance }
  let!(:page) { FactoryBot.create(:pwb_page, slug: "about-us", website: website) }

  describe "GET /api_public/v1/pages/:id" do
    it "returns the page" do
      get "/api_public/v1/pages/#{page.id}"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(page.id)
    end
  end

  describe "GET /api_public/v1/pages/by_slug/:slug" do
    it "returns the page by slug" do
      get "/api_public/v1/pages/by_slug/about-us"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["slug"]).to eq("about-us")
    end
  end
end
