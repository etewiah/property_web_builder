# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiPublic::V1::Hpg::AccessCodes', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'hpg-codes-test') }

  before { host! 'hpg-codes-test.example.com' }

  describe 'POST /api_public/v1/hpg/access_codes/check' do
    it 'returns valid for an active code' do
      create(:pwb_access_code, website: website, code: 'PLAY2025')

      post '/api_public/v1/hpg/access_codes/check', params: { code: 'PLAY2025' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['valid']).to be true
      expect(json['code']).to eq('PLAY2025')
    end

    it 'returns invalid for non-existent code' do
      post '/api_public/v1/hpg/access_codes/check', params: { code: 'FAKE' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['valid']).to be false
    end

    it 'returns invalid for expired code' do
      create(:pwb_access_code, :expired, website: website, code: 'EXPIRED1')

      post '/api_public/v1/hpg/access_codes/check', params: { code: 'EXPIRED1' }

      json = response.parsed_body
      expect(json['valid']).to be false
    end

    it 'returns invalid for exhausted code' do
      create(:pwb_access_code, :exhausted, website: website, code: 'MAXED')

      post '/api_public/v1/hpg/access_codes/check', params: { code: 'MAXED' }

      json = response.parsed_body
      expect(json['valid']).to be false
    end

    it 'returns invalid for inactive code' do
      create(:pwb_access_code, :inactive, website: website, code: 'OFF')

      post '/api_public/v1/hpg/access_codes/check', params: { code: 'OFF' }

      json = response.parsed_body
      expect(json['valid']).to be false
    end

    it 'strips whitespace from code' do
      create(:pwb_access_code, website: website, code: 'TRIMME')

      post '/api_public/v1/hpg/access_codes/check', params: { code: '  TRIMME  ' }

      json = response.parsed_body
      expect(json['valid']).to be true
    end

    it 'does not return codes from other websites' do
      other_website = create(:pwb_website, subdomain: 'other-site')
      create(:pwb_access_code, website: other_website, code: 'OTHERSITE')

      post '/api_public/v1/hpg/access_codes/check', params: { code: 'OTHERSITE' }

      json = response.parsed_body
      expect(json['valid']).to be false
    end
  end
end
