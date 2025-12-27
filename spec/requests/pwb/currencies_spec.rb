# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Currency Selection', type: :request do
  let(:website) do
    create(:pwb_website,
           subdomain: 'currency-test',
           default_currency: 'EUR',
           available_currencies: ['USD', 'GBP'])
  end
  let!(:agency) { create(:pwb_agency, website: website) }

  before do
    # Set up tenant context
    host! "#{website.subdomain}.test.host"
    Pwb::Current.website = website
    ActsAsTenant.current_tenant = website
  end

  describe 'POST /set_currency' do
    context 'with valid currency' do
      it 'sets the currency preference and redirects' do
        post '/set_currency', params: { currency: 'USD' }

        expect(response).to have_http_status(:redirect)
        expect(session[:preferred_currency]).to eq('USD')
      end

      it 'stores currency in cookie' do
        post '/set_currency', params: { currency: 'GBP' }

        expect(cookies[:preferred_currency]).to eq('GBP')
      end

      context 'with JSON format' do
        it 'returns success JSON' do
          post '/set_currency', params: { currency: 'USD' }, as: :json

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['currency']).to eq('USD')
        end
      end
    end

    context 'with invalid currency' do
      it 'redirects with error' do
        post '/set_currency', params: { currency: 'XXX' }

        expect(response).to have_http_status(:redirect)
      end

      context 'with JSON format' do
        it 'returns error JSON' do
          post '/set_currency', params: { currency: 'XXX' }, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          json = JSON.parse(response.body)
          expect(json['success']).to be false
        end
      end
    end

    context 'with currency not in available list' do
      it 'rejects the currency' do
        post '/set_currency', params: { currency: 'JPY' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with blank currency' do
      it 'rejects the request' do
        post '/set_currency', params: { currency: '' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with lowercase currency code' do
      it 'accepts and normalizes to uppercase' do
        post '/set_currency', params: { currency: 'usd' }, as: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['currency']).to eq('USD')
      end
    end
  end
end
