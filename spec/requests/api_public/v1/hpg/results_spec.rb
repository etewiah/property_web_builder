# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiPublic::V1::Hpg::Results', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'hpg-results-test') }

  before { host! 'hpg-results-test.example.com' }

  describe 'GET /api_public/v1/hpg/games/:slug/results/:session_id' do
    let!(:game) { create(:pwb_realty_game, website: website) }
    let!(:asset) { create(:pwb_realty_asset, website: website) }
    let!(:game_listing) { create(:pwb_game_listing, realty_game: game, realty_asset: asset) }
    let!(:session) { create(:pwb_game_session, realty_game: game, website: website, guest_name: 'Bob') }

    before do
      create(:pwb_game_estimate,
             game_session: session,
             game_listing: game_listing,
             website: website,
             estimated_price_cents: 280_000_00,
             actual_price_cents: 300_000_00)
      session.recalculate_total_score!
    end

    it 'returns result board for a session' do
      get "/api_public/v1/hpg/games/#{game.slug}/results/#{session.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['session']['id']).to eq(session.id)
      expect(json['session']['guest_name']).to eq('Bob')
      expect(json['session']['total_score']).to be_a(Integer)
      expect(json['estimates']).to be_an(Array)
      expect(json['estimates'].size).to eq(1)
      expect(json['ranking']['position']).to eq(1)
      expect(json['ranking']['total_players']).to eq(1)
    end

    it 'includes estimate details with property info' do
      get "/api_public/v1/hpg/games/#{game.slug}/results/#{session.id}"

      json = response.parsed_body
      estimate = json['estimates'][0]
      expect(estimate['estimated_price_cents']).to eq(280_000_00)
      expect(estimate['actual_price_cents']).to eq(300_000_00)
      expect(estimate['score']).to be_a(Integer)
      expect(estimate['property']).to be_present
      expect(estimate['property']['city']).to be_present
    end

    it 'computes ranking among multiple players' do
      # Create another session with a higher score
      other_session = create(:pwb_game_session, realty_game: game, website: website, total_score: 999)

      get "/api_public/v1/hpg/games/#{game.slug}/results/#{session.id}"

      json = response.parsed_body
      expect(json['ranking']['total_players']).to eq(2)
      expect(json['ranking']['position']).to be > 1 # someone scored higher
    end

    it 'returns 404 for non-existent session' do
      get "/api_public/v1/hpg/games/#{game.slug}/results/00000000-0000-0000-0000-000000000000"

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-existent game' do
      get "/api_public/v1/hpg/games/nonexistent/results/#{session.id}"

      expect(response).to have_http_status(:not_found)
    end

    it 'includes game info in response' do
      get "/api_public/v1/hpg/games/#{game.slug}/results/#{session.id}"

      json = response.parsed_body
      expect(json['game']['slug']).to eq(game.slug)
      expect(json['game']['title']).to eq(game.title)
    end
  end
end
