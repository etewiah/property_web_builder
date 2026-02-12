# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiPublic::V1::Hpg::Listings', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'hpg-listings-test') }

  before { host! 'hpg-listings-test.example.com' }

  describe 'GET /api_public/v1/hpg/listings/:uuid' do
    it 'returns property details' do
      asset = create(:pwb_realty_asset,
                     website: website,
                     street_address: '10 Downing St',
                     city: 'London',
                     country: 'UK',
                     count_bedrooms: 4,
                     count_bathrooms: 2)

      get "/api_public/v1/hpg/listings/#{asset.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['uuid']).to eq(asset.id)
      expect(json['street_address']).to eq('10 Downing St')
      expect(json['city']).to eq('London')
      expect(json['country']).to eq('UK')
      expect(json['bedrooms']).to eq(4)
      expect(json['bathrooms']).to eq(2)
    end

    it 'includes photos' do
      asset = create(:pwb_realty_asset, :with_photos, website: website)

      get "/api_public/v1/hpg/listings/#{asset.id}"

      json = response.parsed_body
      expect(json['photos']).to be_an(Array)
      expect(json['photos'].size).to eq(2)
      expect(json['photos'][0]).to have_key('id')
      expect(json['photos'][0]).to have_key('url')
    end

    it 'returns 404 for non-existent asset' do
      get '/api_public/v1/hpg/listings/00000000-0000-0000-0000-000000000000'

      expect(response).to have_http_status(:not_found)
    end

    it 'does not return assets from other websites' do
      other_website = create(:pwb_website, subdomain: 'other-listings')
      asset = create(:pwb_realty_asset, website: other_website)

      get "/api_public/v1/hpg/listings/#{asset.id}"

      expect(response).to have_http_status(:not_found)
    end

    it 'includes additional property fields' do
      asset = create(:pwb_realty_asset, :with_location,
                     website: website,
                     postal_code: 'SW1A 2AA',
                     prop_type_key: 'townhouse',
                     constructed_area: 250.0)

      get "/api_public/v1/hpg/listings/#{asset.id}"

      json = response.parsed_body
      expect(json['postal_code']).to eq('SW1A 2AA')
      expect(json['prop_type']).to eq('townhouse')
      expect(json['area_sqm']).to eq(250.0)
      expect(json['latitude']).to be_present
      expect(json['longitude']).to be_present
    end
  end
end
