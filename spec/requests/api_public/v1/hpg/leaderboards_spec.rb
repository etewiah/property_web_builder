# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiPublic::V1::Hpg::Leaderboards', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'hpg-leaderboard-test') }

  before { host! 'hpg-leaderboard-test.example.com' }

  describe 'GET /api_public/v1/hpg/leaderboards' do
    let!(:game) { create(:pwb_realty_game, website: website) }

    it 'returns leaderboard sorted by score descending' do
      create(:pwb_game_session, realty_game: game, website: website, guest_name: 'Low', total_score: 50)
      create(:pwb_game_session, realty_game: game, website: website, guest_name: 'High', total_score: 200)
      create(:pwb_game_session, realty_game: game, website: website, guest_name: 'Mid', total_score: 100)

      get '/api_public/v1/hpg/leaderboards'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['data'].size).to eq(3)
      names = json['data'].map { |d| d['guest_name'] }
      expect(names).to eq(%w[High Mid Low])
      expect(json['data'][0]['rank']).to eq(1)
      expect(json['data'][2]['rank']).to eq(3)
    end

    it 'filters by game_slug' do
      game2 = create(:pwb_realty_game, website: website)
      create(:pwb_game_session, realty_game: game, website: website, guest_name: 'P1', total_score: 100)
      create(:pwb_game_session, realty_game: game2, website: website, guest_name: 'P2', total_score: 200)

      get '/api_public/v1/hpg/leaderboards', params: { game_slug: game.slug }

      json = response.parsed_body
      expect(json['data'].size).to eq(1)
      expect(json['data'][0]['guest_name']).to eq('P1')
      expect(json['meta']['game_slug']).to eq(game.slug)
    end

    it 'filters by period' do
      create(:pwb_game_session, realty_game: game, website: website, guest_name: 'Recent', total_score: 100)
      old_session = create(:pwb_game_session, realty_game: game, website: website, guest_name: 'Old', total_score: 200)
      old_session.update_column(:created_at, 2.weeks.ago)

      get '/api_public/v1/hpg/leaderboards', params: { period: 'weekly' }

      json = response.parsed_body
      expect(json['data'].size).to eq(1)
      expect(json['data'][0]['guest_name']).to eq('Recent')
      expect(json['meta']['period']).to eq('weekly')
    end

    it 'respects limit parameter' do
      5.times { |i| create(:pwb_game_session, realty_game: game, website: website, total_score: i * 10) }

      get '/api_public/v1/hpg/leaderboards', params: { limit: 2 }

      json = response.parsed_body
      expect(json['data'].size).to eq(2)
    end

    it 'caps limit at 100' do
      get '/api_public/v1/hpg/leaderboards', params: { limit: 999 }

      expect(response).to have_http_status(:ok)
      # No error — just capped internally
    end

    it 'returns empty data when no sessions exist' do
      get '/api_public/v1/hpg/leaderboards'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['data']).to eq([])
    end

    it 'includes game info in each entry' do
      create(:pwb_game_session, realty_game: game, website: website, total_score: 100)

      get '/api_public/v1/hpg/leaderboards'

      json = response.parsed_body
      entry = json['data'][0]
      expect(entry['game_slug']).to eq(game.slug)
      expect(entry['game_title']).to eq(game.title)
    end
  end
end
