# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiPublic::V1::ThemeSettings', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'palette-site', slug: 'palette-site', theme_name: 'default') }
  let(:path) { '/api_public/v1/theme_settings/palette' }

  before do
    host! 'palette-site.localhost'
  end

  describe 'PATCH /api_public/v1/theme_settings/palette' do
    it 'returns bad request when no website context can be resolved' do
      host! 'unknown.example.com'

      patch path, params: { palette_id: 'ocean_blue' }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('Website context required')
    end

    it 'requires authentication when no admin session or API key is provided' do
      patch path, params: { palette_id: 'ocean_blue' }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['error']).to eq('Authentication required')
      expect(website.reload.selected_palette).not_to eq('ocean_blue')
    end

    it 'forbids non-admin users for the current website' do
      user = create(:pwb_user, website: website)
      create(:pwb_user_membership, :member, user: user, website: website)
      sign_in user

      patch path, params: { palette_id: 'ocean_blue' }

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']).to eq('Admin access required')
      expect(website.reload.selected_palette).not_to eq('ocean_blue')
    end

    it 'allows a website admin to update the palette' do
      admin = create(:pwb_user, :admin, website: website)
      sign_in admin

      patch path, params: { palette_id: 'ocean_blue' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'palette_id')).to eq('ocean_blue')
      expect(website.reload.selected_palette).to eq('ocean_blue')
    end

    it 'allows valid API keys for the current website and records usage' do
      integration = create(:pwb_website_integration, website: website, credentials: { 'api_key' => 'secret-api-key' })

      patch path,
            params: { palette_id: 'ocean_blue' },
            headers: { 'X-API-Key' => 'secret-api-key' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'palette_id')).to eq('ocean_blue')
      expect(website.reload.selected_palette).to eq('ocean_blue')
      expect(integration.reload.last_used_at).to be_present
    end
  end
end