# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::Theme", type: :request do
  let(:website) { create(:pwb_website) }
  
  before do
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  describe "GET /api_public/v1/theme" do
    it "returns theme configuration" do
      get "/api_public/v1/theme"
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json["theme"]).to be_present
      expect(json["theme"]["name"]).to be_present
      expect(json["theme"]["colors"]).to be_a(Hash)
    end

    it "includes CSS variables" do
      get "/api_public/v1/theme"
      
      json = JSON.parse(response.body)
      expect(json["theme"]["css_variables"]).to be_present
    end

    it "includes dark mode configuration" do
      get "/api_public/v1/theme"
      
      json = JSON.parse(response.body)
      expect(json["theme"]["dark_mode"]).to be_present
      expect(json["theme"]["dark_mode"]["enabled"]).to be_in([true, false])
      expect(json["theme"]["dark_mode"]["setting"]).to be_present
    end

    it "includes font configuration" do
      get "/api_public/v1/theme"
      
      json = JSON.parse(response.body)
      expect(json["theme"]["fonts"]).to have_key("heading")
      expect(json["theme"]["fonts"]).to have_key("body")
    end

    it "includes border radius configuration" do
      get "/api_public/v1/theme"
      
      json = JSON.parse(response.body)
      expect(json["theme"]["border_radius"]).to be_a(Hash)
      expect(json["theme"]["border_radius"]).to have_key("sm")
      expect(json["theme"]["border_radius"]).to have_key("md")
      expect(json["theme"]["border_radius"]).to have_key("lg")
      expect(json["theme"]["border_radius"]).to have_key("xl")
    end
  end
end
