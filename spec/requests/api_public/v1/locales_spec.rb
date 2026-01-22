# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ApiPublic::V1::Locales", type: :request do
  let(:website) { create(:website) }

  before do
    allow(Pwb::Current).to receive(:website).and_return(website)
    host! "#{website.subdomain}.localhost"
  end

  describe "GET /api_public/v1/locales" do
    it "returns available locales" do
      get "/api_public/v1/locales"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to have_key("default_locale")
      expect(json).to have_key("available_locales")
      expect(json).to have_key("current_locale")
      expect(json["available_locales"]).to be_an(Array)
    end

    it "includes locale metadata" do
      get "/api_public/v1/locales"

      json = JSON.parse(response.body)
      locale = json["available_locales"].first

      expect(locale).to have_key("code")
      expect(locale).to have_key("name")
      expect(locale).to have_key("native_name")
      expect(locale).to have_key("flag_emoji")
    end

    context "when website has custom enabled locales" do
      before do
        allow(website).to receive(:enabled_locales).and_return(%w[en es fr])
        allow(website).to receive(:respond_to?).and_call_original
        allow(website).to receive(:respond_to?).with(:enabled_locales).and_return(true)
      end

      it "returns only enabled locales" do
        get "/api_public/v1/locales"

        json = JSON.parse(response.body)
        codes = json["available_locales"].map { |l| l["code"] }

        expect(codes).to match_array(%w[en es fr])
      end
    end
  end
end
