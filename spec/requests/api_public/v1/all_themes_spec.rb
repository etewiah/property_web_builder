require 'rails_helper'

RSpec.describe "ApiPublic::V1::AllThemes", type: :request do
  describe "GET /api_public/v1/all-themes" do
    it "returns a list of enabled themes" do
      get "/api_public/v1/all-themes"

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response["meta"]["version"]).to eq("1.0")
      expect(json_response["data"]).to be_an(Array)
      expect(json_response["meta"]["total"]).to eq(json_response["data"].length)

      # Verify structure of the first theme
      if json_response["data"].any?
        theme = json_response["data"].first
        expect(theme).to have_key("name")
        expect(theme).to have_key("description")
        expect(theme).to have_key("css_variables")
        expect(theme).to have_key("palettes")
        
        expect(theme["palettes"]).to be_an(Array)
        if theme["palettes"].any?
          palette = theme["palettes"].first
          expect(palette).to have_key("id")
          expect(palette).to have_key("name")
          expect(palette).to have_key("colors")
          expect(palette["colors"]).to be_a(Hash)
        end
      end
    end

    it "matches Pwb::Theme.enabled count" do
      enabled_count = Pwb::Theme.enabled.count
      get "/api_public/v1/all-themes"
      
      json_response = JSON.parse(response.body)
      expect(json_response["meta"]["total"]).to eq(enabled_count)
      expect(json_response["data"].length).to eq(enabled_count)
    end
  end
end
