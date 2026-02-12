# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiPublic::V1::Hpg::Estimates', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'hpg-estimates-test') }

  before { host! 'hpg-estimates-test.example.com' }

  describe 'POST /api_public/v1/hpg/games/:slug/estimates' do
    let!(:game) { create(:pwb_realty_game, website: website) }
    let!(:asset) { create(:pwb_realty_asset, website: website) }
    let!(:game_listing) { create(:pwb_game_listing, realty_game: game, realty_asset: asset) }

    before do
      # Create a sale listing so actual_price_cents is non-zero
      create(:pwb_sale_listing, :visible, realty_asset: asset, price_sale_current_cents: 300_000_00)
    end

    let(:valid_params) do
      {
        price_estimate: {
          game_listing_id: game_listing.id,
          estimated_price: 280_000,
          currency: 'EUR',
          visitor_token: 'test-token-123',
          guest_name: 'Alice',
          property_index: 0
        }
      }
    end

    it 'creates a new estimate and session' do
      expect {
        post "/api_public/v1/hpg/games/#{game.slug}/estimates", params: valid_params
      }.to change(Pwb::GameEstimate, :count).by(1)
        .and change(Pwb::GameSession, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['estimate']['estimated_price_cents']).to eq(280_000_00)
      expect(json['estimate']['actual_price_cents']).to eq(300_000_00)
      expect(json['estimate']['score']).to be_a(Integer)
      expect(json['session']['id']).to be_present
      expect(json['session']['total_score']).to be_a(Integer)
    end

    it 'reuses existing session when session_id provided' do
      session = create(:pwb_game_session, realty_game: game, website: website)

      expect {
        post "/api_public/v1/hpg/games/#{game.slug}/estimates",
             params: { price_estimate: valid_params[:price_estimate].merge(session_id: session.id) }
      }.to change(Pwb::GameEstimate, :count).by(1)
        .and change(Pwb::GameSession, :count).by(0)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['session']['id']).to eq(session.id)
    end

    it 'returns conflict for duplicate estimate' do
      session = create(:pwb_game_session, realty_game: game, website: website)
      create(:pwb_game_estimate,
             game_session: session,
             game_listing: game_listing,
             website: website,
             estimated_price_cents: 250_000_00,
             actual_price_cents: 300_000_00)

      post "/api_public/v1/hpg/games/#{game.slug}/estimates",
           params: { price_estimate: valid_params[:price_estimate].merge(session_id: session.id) }

      expect(response).to have_http_status(:conflict)
      json = response.parsed_body
      expect(json['error']['code']).to eq('DUPLICATE_ESTIMATE')
    end

    it 'returns 404 for non-existent game' do
      post '/api_public/v1/hpg/games/nonexistent/estimates', params: valid_params

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-existent game_listing_id' do
      bad_params = {
        price_estimate: valid_params[:price_estimate].merge(
          game_listing_id: '00000000-0000-0000-0000-000000000000'
        )
      }

      post "/api_public/v1/hpg/games/#{game.slug}/estimates", params: bad_params

      expect(response).to have_http_status(:not_found)
    end

    it 'includes score feedback in response' do
      post "/api_public/v1/hpg/games/#{game.slug}/estimates", params: valid_params

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['estimate']['feedback']).to be_present
      expect(json['estimate']['emoji']).to be_present
      expect(json['estimate']['percentage_diff']).to be_present
    end
  end
end
