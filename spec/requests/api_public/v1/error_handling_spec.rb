# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ApiPublic::V1 Error Handling", type: :request do
  let!(:website) { create(:pwb_website) }

  before do
    host! "#{website.subdomain}.example.com"
  end

  describe "standardized error responses" do
    context "when property not found" do
      it "returns structured error with code" do
        get "/api_public/v1/properties/nonexistent-slug"

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body

        expect(json["error"]).to be_present
        expect(json["error"]["code"]).to eq("NOT_FOUND").or eq("PROPERTY_NOT_FOUND")
        expect(json["error"]["status"]).to eq(404)
        expect(json["error"]["request_id"]).to be_present
      end
    end

    context "when page not found" do
      it "returns structured error with code" do
        get "/api_public/v1/pages/9999999"

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body

        expect(json["error"]).to be_present
        expect(json["error"]["code"]).to eq("NOT_FOUND").or eq("PAGE_NOT_FOUND")
      end
    end
  end

  describe "error response format" do
    it "includes request_id for debugging" do
      get "/api_public/v1/properties/nonexistent"

      json = response.parsed_body
      expect(json.dig("error", "request_id")).to match(/\A[a-f0-9-]+\z/i)
    end
  end
end
