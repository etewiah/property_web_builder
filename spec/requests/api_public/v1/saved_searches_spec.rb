# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ApiPublic::V1::SavedSearches", type: :request do
  let(:website) { create(:website) }
  let(:email) { "user@example.com" }

  before do
    # Set up tenant context
    allow(Pwb::Current).to receive(:website).and_return(website)
    host! website.host
  end

  describe "POST /api_public/v1/saved_searches" do
    let(:valid_params) do
      {
        saved_search: {
          email: email,
          name: "My search",
          alert_frequency: "daily",
          search_criteria: {
            sale_or_rental: "sale",
            property_type: "apartment",
            bedrooms_from: 2,
            price_from: 100_000,
            price_to: 500_000
          }
        }
      }
    end

    it "creates a new saved search" do
      expect do
        post "/api_public/v1/saved_searches", params: valid_params, as: :json
      end.to change { saved_search_class.count }.by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["saved_search"]["email"]).to eq(email)
      expect(json["saved_search"]["alert_frequency"]).to eq("daily")
      expect(json["manage_token"]).to be_present
    end

    it "returns errors for invalid params" do
      post "/api_public/v1/saved_searches",
           params: { saved_search: { email: "" } },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["errors"]).to be_present
    end
  end

  describe "GET /api_public/v1/saved_searches" do
    let!(:saved_search) { create_saved_search(email: email) }

    it "returns saved searches for token" do
      get "/api_public/v1/saved_searches", params: { token: saved_search.manage_token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["email"]).to eq(email)
      expect(json["saved_searches"]).to be_an(Array)
      expect(json["saved_searches"].first["id"]).to eq(saved_search.id)
    end

    it "returns unauthorized for invalid token" do
      get "/api_public/v1/saved_searches", params: { token: "invalid" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api_public/v1/saved_searches/:id" do
    let!(:saved_search) { create_saved_search(email: email) }

    it "returns a single saved search with alerts" do
      get "/api_public/v1/saved_searches/#{saved_search.id}",
          params: { token: saved_search.manage_token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(saved_search.id)
      expect(json).to have_key("recent_alerts")
    end
  end

  describe "PATCH /api_public/v1/saved_searches/:id" do
    let!(:saved_search) { create_saved_search(email: email, alert_frequency: :daily) }

    it "updates alert frequency" do
      patch "/api_public/v1/saved_searches/#{saved_search.id}",
            params: {
              token: saved_search.manage_token,
              saved_search: { alert_frequency: "weekly" }
            },
            as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(saved_search.reload.alert_frequency).to eq("weekly")
    end

    it "can disable the search" do
      patch "/api_public/v1/saved_searches/#{saved_search.id}",
            params: {
              token: saved_search.manage_token,
              saved_search: { enabled: false }
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(saved_search.reload.enabled).to be false
    end
  end

  describe "DELETE /api_public/v1/saved_searches/:id" do
    let!(:saved_search) { create_saved_search(email: email) }

    it "deletes the saved search" do
      expect do
        delete "/api_public/v1/saved_searches/#{saved_search.id}",
               params: { token: saved_search.manage_token }
      end.to change { saved_search_class.count }.by(-1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end
  end

  describe "POST /api_public/v1/saved_searches/:id/unsubscribe" do
    let!(:saved_search) { create_saved_search(email: email, alert_frequency: :daily) }

    it "unsubscribes from alerts" do
      post "/api_public/v1/saved_searches/#{saved_search.id}/unsubscribe",
           params: { token: saved_search.manage_token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true

      saved_search.reload
      expect(saved_search.enabled).to be false
      expect(saved_search.alert_frequency).to eq("none")
    end

    it "works with unsubscribe token" do
      post "/api_public/v1/saved_searches/#{saved_search.id}/unsubscribe",
           params: { token: saved_search.unsubscribe_token }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api_public/v1/saved_searches/verify" do
    let!(:saved_search) { create_saved_search(email: email) }

    it "verifies email with valid token" do
      get "/api_public/v1/saved_searches/verify",
          params: { token: saved_search.verification_token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end

    it "returns not found for invalid token" do
      get "/api_public/v1/saved_searches/verify", params: { token: "invalid" }

      expect(response).to have_http_status(:not_found)
    end
  end

  private

  def saved_search_class
    defined?(PwbTenant::SavedSearch) ? PwbTenant::SavedSearch : Pwb::SavedSearch
  end

  def create_saved_search(attrs = {})
    saved_search_class.create!(
      website: website,
      email: attrs[:email] || email,
      name: attrs[:name] || "Test Search",
      alert_frequency: attrs[:alert_frequency] || :none,
      search_criteria: attrs[:search_criteria] || { sale_or_rental: "sale" }
    )
  end
end
