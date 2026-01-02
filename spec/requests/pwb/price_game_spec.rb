# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Price Game", type: :request do
  let(:website) { create(:pwb_website) }
  let(:realty_asset) { create(:pwb_realty_asset, website: website) }
  let(:sale_listing) do
    sl = create(:pwb_sale_listing,
                realty_asset: realty_asset,
                price_sale_current_cents: 300_000_00,
                price_sale_current_currency: "EUR",
                game_enabled: true)
    sl.generate_game_token
    sl.save!
    sl
  end

  before do
    allow_any_instance_of(Pwb::ApplicationController).to receive(:current_website).and_return(website)
  end

  describe "GET /g/:token" do
    context "when game is enabled" do
      it "returns success" do
        get price_game_path(token: sale_listing.game_token)
        expect(response).to have_http_status(:success)
      end

      it "does not reveal the price" do
        get price_game_path(token: sale_listing.game_token)
        # The actual price should not be visible on the page
        expect(response.body).not_to include("300,000")
        expect(response.body).not_to include("300000")
      end

      it "increments view count" do
        expect do
          get price_game_path(token: sale_listing.game_token)
        end.to change { sale_listing.reload.game_views_count }.by(1)
      end

      it "renders the game heading" do
        get price_game_path(token: sale_listing.game_token)
        expect(response.body).to include("Guess the Price")
      end
    end

    context "when game is disabled" do
      before { sale_listing.update!(game_enabled: false) }

      it "returns 404" do
        get price_game_path(token: sale_listing.game_token)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when token is invalid" do
      it "returns 404" do
        get price_game_path(token: "invalid-token")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /g/:token/guess" do
    let(:visitor_token) { SecureRandom.urlsafe_base64(16) }

    before do
      cookies[:price_game_visitor] = visitor_token
    end

    context "with a valid guess" do
      it "creates a price guess" do
        expect do
          post price_game_guess_path(token: sale_listing.game_token),
               params: { guessed_price: 280000, currency: "EUR" },
               as: :json
        end.to change(Pwb::PriceGuess, :count).by(1)

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["guess"]["score"]).to be_present
      end

      it "returns the leaderboard" do
        post price_game_guess_path(token: sale_listing.game_token),
             params: { guessed_price: 280000, currency: "EUR" },
             as: :json

        json = JSON.parse(response.body)
        expect(json["leaderboard"]).to be_an(Array)
      end
    end

    context "when visitor has already guessed" do
      before do
        Pwb::PriceGuess.create!(
          listing: sale_listing,
          website: website,
          visitor_token: visitor_token,
          guessed_price_cents: 250_000_00
        )
      end

      it "returns error" do
        post price_game_guess_path(token: sale_listing.game_token),
             params: { guessed_price: 280000, currency: "EUR" },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
      end
    end

    context "with invalid guess (zero or negative)" do
      it "returns error" do
        post price_game_guess_path(token: sale_listing.game_token),
             params: { guessed_price: 0, currency: "EUR" },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /g/:token/share" do
    it "increments share count" do
      expect do
        post price_game_share_path(token: sale_listing.game_token), as: :json
      end.to change { sale_listing.reload.game_shares_count }.by(1)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end
  end
end
