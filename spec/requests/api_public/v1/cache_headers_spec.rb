# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiPublic::V1 Cache Headers', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'cache-test') }
  let!(:realty_asset) { create(:pwb_realty_asset, website: website) }
  let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: realty_asset) }

  before do
    Pwb::ListedProperty.refresh(concurrently: false)
  end

  describe 'property detail endpoint' do
    it 'returns cache headers with max-age of 1 hour or less' do
      host! 'cache-test.example.com'
      get "/api_public/v1/properties/#{realty_asset.id}"

      expect(response).to have_http_status(:ok)
      cache_control = response.headers['Cache-Control']
      expect(cache_control).to include('public')
      max_age = cache_control[/max-age=(\d+)/, 1].to_i
      expect(max_age).to be <= 3600, "Expected max-age <= 3600 (1 hour), got #{max_age}"
    end

    it 'does not use the old 5-hour cache default' do
      host! 'cache-test.example.com'
      get "/api_public/v1/properties/#{realty_asset.id}"

      cache_control = response.headers['Cache-Control']
      max_age = cache_control[/max-age=(\d+)/, 1].to_i
      expect(max_age).not_to eq(18000), 'Should not use old 5-hour (18000s) default'
    end
  end

  describe 'property search endpoint' do
    it 'returns cache headers with max-age of 1 hour or less' do
      host! 'cache-test.example.com'
      get '/api_public/v1/properties', params: { sale_or_rental: 'sale' }

      expect(response).to have_http_status(:ok)
      cache_control = response.headers['Cache-Control']
      expect(cache_control).to include('public')
      max_age = cache_control[/max-age=(\d+)/, 1].to_i
      expect(max_age).to be <= 3600
    end
  end
end
