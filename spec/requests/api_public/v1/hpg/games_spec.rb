# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiPublic::V1::Hpg::Games', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'hpg-games-test') }

  before { host! 'hpg-games-test.example.com' }

  describe 'GET /api_public/v1/hpg/games' do
    it 'returns active, visible games for current website' do
      game = create(:pwb_realty_game, website: website, active: true, hidden_from_landing_page: false)
      create(:pwb_realty_game, :inactive, website: website)
      create(:pwb_realty_game, :hidden, website: website)

      get '/api_public/v1/hpg/games'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['data'].size).to eq(1)
      expect(json['data'][0]['slug']).to eq(game.slug)
      expect(json['meta']['total']).to eq(1)
    end

    it 'returns empty array when no games exist' do
      get '/api_public/v1/hpg/games'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['data']).to eq([])
    end

    it 'filters by date availability' do
      create(:pwb_realty_game, website: website, start_at: 1.day.from_now)
      available = create(:pwb_realty_game, website: website, start_at: 1.day.ago, end_at: 1.day.from_now)

      get '/api_public/v1/hpg/games'

      json = response.parsed_body
      slugs = json['data'].map { |g| g['slug'] }
      expect(slugs).to include(available.slug)
    end
  end

  describe 'GET /api_public/v1/hpg/games/:slug' do
    it 'returns game with listings' do
      game = create(:pwb_realty_game, website: website)
      asset = create(:pwb_realty_asset, website: website, street_address: '10 Downing St', city: 'London')
      create(:pwb_game_listing, realty_game: game, realty_asset: asset)

      get "/api_public/v1/hpg/games/#{game.slug}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['slug']).to eq(game.slug)
      expect(json['listings'].size).to eq(1)
      expect(json['listings'][0]['property']['city']).to eq('London')
    end

    it 'returns 404 for non-existent game' do
      get '/api_public/v1/hpg/games/nonexistent'

      expect(response).to have_http_status(:not_found)
    end

    it 'excludes hidden listings' do
      game = create(:pwb_realty_game, website: website)
      asset1 = create(:pwb_realty_asset, website: website)
      asset2 = create(:pwb_realty_asset, website: website)
      create(:pwb_game_listing, realty_game: game, realty_asset: asset1, visible: true)
      create(:pwb_game_listing, realty_game: game, realty_asset: asset2, visible: false)

      get "/api_public/v1/hpg/games/#{game.slug}"

      json = response.parsed_body
      expect(json['listings'].size).to eq(1)
    end
  end
end
