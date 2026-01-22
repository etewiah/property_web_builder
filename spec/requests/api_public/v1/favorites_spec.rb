# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ApiPublic::V1::Favorites", type: :request do
  let(:website) { create(:website) }
  let(:email) { "user@example.com" }

  before do
    # Set up tenant context
    allow(Pwb::Current).to receive(:website).and_return(website)
    host! "#{website.subdomain}.localhost"
  end

  describe "POST /api_public/v1/favorites" do
    let(:valid_params) do
      {
        favorite: {
          email: email,
          provider: "internal",
          external_reference: "prop-123",
          notes: "Nice property",
          property_data: {
            title: "Beautiful Villa",
            price: { cents: 50_000_000, currency_iso: "EUR" },
            image_url: "https://example.com/image.jpg"
          }
        }
      }
    end

    it "creates a new favorite" do
      expect do
        post "/api_public/v1/favorites", params: valid_params, as: :json
      end.to change { saved_property_class.count }.by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["favorite"]["email"]).to eq(email)
      expect(json["manage_token"]).to be_present
    end

    it "returns errors for invalid params" do
      post "/api_public/v1/favorites", params: { favorite: { email: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["errors"]).to be_present
    end
  end

  describe "GET /api_public/v1/favorites" do
    let!(:favorite) { create_favorite(email: email) }

    it "returns favorites for token" do
      get "/api_public/v1/favorites", params: { token: favorite.manage_token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["email"]).to eq(email)
      expect(json["favorites"]).to be_an(Array)
      expect(json["favorites"].first["id"]).to eq(favorite.id)
    end

    it "returns unauthorized for invalid token" do
      get "/api_public/v1/favorites", params: { token: "invalid" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api_public/v1/favorites/:id" do
    let!(:favorite) { create_favorite(email: email) }

    it "returns a single favorite" do
      get "/api_public/v1/favorites/#{favorite.id}", params: { token: favorite.manage_token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(favorite.id)
    end
  end

  describe "PATCH /api_public/v1/favorites/:id" do
    let!(:favorite) { create_favorite(email: email) }

    it "updates notes" do
      patch "/api_public/v1/favorites/#{favorite.id}",
            params: { token: favorite.manage_token, favorite: { notes: "Updated notes" } },
            as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(favorite.reload.notes).to eq("Updated notes")
    end
  end

  describe "DELETE /api_public/v1/favorites/:id" do
    let!(:favorite) { create_favorite(email: email) }

    it "deletes the favorite" do
      expect do
        delete "/api_public/v1/favorites/#{favorite.id}", params: { token: favorite.manage_token }
      end.to change { saved_property_class.count }.by(-1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end
  end

  describe "POST /api_public/v1/favorites/check" do
    let!(:favorite) { create_favorite(email: email, external_reference: "prop-123") }

    it "returns saved references" do
      post "/api_public/v1/favorites/check",
           params: { email: email, references: %w[prop-123 prop-456] },
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["saved"]).to eq(["prop-123"])
    end
  end

  private

  def saved_property_class
    defined?(PwbTenant::SavedProperty) ? PwbTenant::SavedProperty : Pwb::SavedProperty
  end

  def create_favorite(attrs = {})
    saved_property_class.create!(
      website: website,
      email: attrs[:email] || email,
      provider: attrs[:provider] || "internal",
      external_reference: attrs[:external_reference] || "prop-#{SecureRandom.hex(4)}",
      notes: attrs[:notes],
      property_data: attrs[:property_data] || { title: "Test Property" }
    )
  end
end
