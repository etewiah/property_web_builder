# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Property Search', type: :request do
  let!(:website) { create(:pwb_website) }

  before do
    host! "#{website.subdomain}.example.com"
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /buy' do
    it 'renders search page successfully' do
      get '/en/buy'
      expect(response).to have_http_status(:success)
    end

    it 'includes search results container' do
      get '/en/buy'
      expect(response.body).to include('search-results')
    end
  end

  describe 'GET /rent' do
    it 'renders rent search page successfully' do
      get '/en/rent'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'URL parameter handling' do
    it 'accepts type parameter' do
      get '/en/buy', params: { type: 'apartment' }
      expect(response).to have_http_status(:success)
    end

    it 'accepts bedrooms parameter' do
      get '/en/buy', params: { bedrooms: 2 }
      expect(response).to have_http_status(:success)
    end

    it 'accepts price range parameters' do
      get '/en/buy', params: { price_min: 100_000, price_max: 500_000 }
      expect(response).to have_http_status(:success)
    end

    it 'accepts sort parameter' do
      get '/en/buy', params: { sort: 'price-asc' }
      expect(response).to have_http_status(:success)
    end

    it 'accepts view parameter' do
      get '/en/buy', params: { view: 'list' }
      expect(response).to have_http_status(:success)
    end

    it 'accepts page parameter' do
      get '/en/buy', params: { page: 2 }
      expect(response).to have_http_status(:success)
    end

    it 'accepts multiple parameters' do
      get '/en/buy', params: {
        type: 'apartment',
        bedrooms: 2,
        price_min: 100_000,
        sort: 'price-desc'
      }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'error handling' do
    it 'handles malformed parameters gracefully' do
      get '/en/buy', params: { bedrooms: 'not-a-number' }
      expect(response).to have_http_status(:success)
    end

    it 'ignores unknown parameters' do
      get '/en/buy', params: { unknown_param: 'value' }
      expect(response).to have_http_status(:success)
    end

    it 'handles XSS attempts in parameters' do
      get '/en/buy', params: { type: '<script>alert("xss")</script>' }
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('<script>alert')
    end
  end

  describe 'Turbo Frame requests' do
    it 'responds to Turbo Frame requests' do
      get '/en/buy', headers: { 'Turbo-Frame' => 'search-results' }
      expect(response).to have_http_status(:success)
    end

    it 'applies filters in Turbo Frame request' do
      get '/en/buy',
          params: { type: 'apartment' },
          headers: { 'Turbo-Frame' => 'search-results' }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'SEO' do
    it 'includes canonical URL meta tag' do
      get '/en/buy', params: { type: 'apartment' }
      expect(response.body).to include('canonical')
    end
  end
end
