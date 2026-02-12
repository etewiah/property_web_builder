# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'HPG CORS Headers', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'hpg-cors-test') }

  before do
    host! 'hpg-cors-test.example.com'
  end

  describe 'HPG production origin' do
    it 'returns CORS headers for housepriceguess.com' do
      get '/api_public/v1/hpg/games',
          headers: { 'Origin' => 'https://housepriceguess.com' }

      expect(response.headers['Access-Control-Allow-Origin']).to eq('https://housepriceguess.com')
    end

    it 'returns CORS headers for subdomain of housepriceguess.com' do
      get '/api_public/v1/hpg/games',
          headers: { 'Origin' => 'https://london.housepriceguess.com' }

      expect(response.headers['Access-Control-Allow-Origin']).to eq('https://london.housepriceguess.com')
    end
  end

  describe 'development origin' do
    it 'returns CORS headers for localhost:4321' do
      get '/api_public/v1/hpg/games',
          headers: { 'Origin' => 'http://localhost:4321' }

      expect(response.headers['Access-Control-Allow-Origin']).to eq('http://localhost:4321')
    end
  end
end
