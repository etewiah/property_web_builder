# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pwb::PropsController', type: :request do
  # Public property browsing - show pages for rent and sale listings
  # Must verify: property display, not found handling, multi-tenancy

  let!(:website) { create(:pwb_website, subdomain: 'props-public-test') }
  let!(:agency) { create(:pwb_agency, website: website, email_primary: 'agency@props-public.test') }

  before do
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  describe 'GET /properties/for-rent/:id (show_for_rent)' do
    context 'with non-existent property' do
      it 'returns not found status for non-existent slug' do
        get '/properties/for-rent/nonexistent-slug',
            headers: { 'HTTP_HOST' => 'props-public-test.test.localhost' }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found status for non-existent ID' do
        get '/properties/for-rent/12345678',
            headers: { 'HTTP_HOST' => 'props-public-test.test.localhost' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /properties/for-sale/:id (show_for_sale)' do
    context 'with non-existent property' do
      it 'returns not found status for non-existent slug' do
        get '/properties/for-sale/nonexistent-slug',
            headers: { 'HTTP_HOST' => 'props-public-test.test.localhost' }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found status for non-existent ID' do
        get '/properties/for-sale/12345678',
            headers: { 'HTTP_HOST' => 'props-public-test.test.localhost' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'no authentication required' do
    # Public pages should work without authentication

    it 'allows unauthenticated access to for-rent page' do
      get '/properties/for-rent/test-property',
          headers: { 'HTTP_HOST' => 'props-public-test.test.localhost' }

      # Not found is OK, but should not be 401/403/redirect to login
      expect(response).to have_http_status(:not_found)
      expect(response).not_to have_http_status(:unauthorized)
      expect(response).not_to have_http_status(:forbidden)
    end

    it 'allows unauthenticated access to for-sale page' do
      get '/properties/for-sale/test-property',
          headers: { 'HTTP_HOST' => 'props-public-test.test.localhost' }

      # Not found is OK, but should not be 401/403/redirect to login
      expect(response).to have_http_status(:not_found)
      expect(response).not_to have_http_status(:unauthorized)
      expect(response).not_to have_http_status(:forbidden)
    end
  end
end
