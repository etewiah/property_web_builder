# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiPublic::V1::Hpg Cross-Tenant Isolation', type: :request do
  let!(:website_a) { create(:pwb_website, subdomain: 'hpg-tenant-a') }
  let!(:website_b) { create(:pwb_website, subdomain: 'hpg-tenant-b') }

  describe 'games isolation' do
    it 'only returns games belonging to the requesting website' do
      game_a = create(:pwb_realty_game, website: website_a, title: 'Game A')
      create(:pwb_realty_game, website: website_b, title: 'Game B')

      host! 'hpg-tenant-a.example.com'
      get '/api_public/v1/hpg/games'

      json = response.parsed_body
      titles = json['data'].map { |g| g['title'] }
      expect(titles).to include('Game A')
      expect(titles).not_to include('Game B')
    end

    it 'cannot access another website game by slug' do
      create(:pwb_realty_game, website: website_b, slug: 'secret-game')

      host! 'hpg-tenant-a.example.com'
      get '/api_public/v1/hpg/games/secret-game'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'leaderboard isolation' do
    it 'only shows sessions from the requesting website' do
      game_a = create(:pwb_realty_game, website: website_a)
      game_b = create(:pwb_realty_game, website: website_b)
      create(:pwb_game_session, realty_game: game_a, website: website_a, guest_name: 'Player A', total_score: 100)
      create(:pwb_game_session, realty_game: game_b, website: website_b, guest_name: 'Player B', total_score: 200)

      host! 'hpg-tenant-a.example.com'
      get '/api_public/v1/hpg/leaderboards'

      json = response.parsed_body
      names = json['data'].map { |d| d['guest_name'] }
      expect(names).to include('Player A')
      expect(names).not_to include('Player B')
    end
  end

  describe 'access codes isolation' do
    it 'does not validate codes from another website' do
      create(:pwb_access_code, website: website_b, code: 'TENANT-B-CODE')

      host! 'hpg-tenant-a.example.com'
      post '/api_public/v1/hpg/access_codes/check', params: { code: 'TENANT-B-CODE' }

      json = response.parsed_body
      expect(json['valid']).to be false
    end
  end

  describe 'listings isolation' do
    it 'does not return assets from another website' do
      asset_b = create(:pwb_realty_asset, website: website_b)

      host! 'hpg-tenant-a.example.com'
      get "/api_public/v1/hpg/listings/#{asset_b.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'estimates isolation' do
    it 'cannot submit estimates to another website game' do
      game_b = create(:pwb_realty_game, website: website_b)
      asset_b = create(:pwb_realty_asset, website: website_b)
      listing_b = create(:pwb_game_listing, realty_game: game_b, realty_asset: asset_b)

      host! 'hpg-tenant-a.example.com'
      post "/api_public/v1/hpg/games/#{game_b.slug}/estimates", params: {
        price_estimate: {
          game_listing_id: listing_b.id,
          estimated_price: 100_000,
          visitor_token: 'attacker',
          guest_name: 'Hacker'
        }
      }

      expect(response).to have_http_status(:not_found)
    end
  end
end
