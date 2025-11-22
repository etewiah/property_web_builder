require 'rails_helper'

RSpec.describe "ApiPublic::V1::Translations", type: :request do
  describe "GET /api_public/v1/translations" do
    it "returns translations for a locale" do
      get "/api_public/v1/translations", params: { locale: "en" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["locale"]).to eq("en")
      expect(json["result"]).to be_present
    end

    it "returns error if locale is missing" do
      get "/api_public/v1/translations"
      expect(response).to have_http_status(400)
    end
  end
end
