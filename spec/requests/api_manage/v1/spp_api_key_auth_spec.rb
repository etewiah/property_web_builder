# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SPP API Key Authentication', type: :request do
  let!(:website) { create(:pwb_website) }
  let!(:user) { create(:pwb_user, :admin, website: website) }
  let!(:property) { create(:pwb_realty_asset, website: website) }
  let!(:integration) { create(:pwb_website_integration, :spp, website: website) }

  let(:api_key) { integration.credential('api_key') }

  before do
    website.update!(client_theme_config: { 'spp_url_template' => 'https://{slug}.spp.example.com/' })
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'authenticating with X-API-Key header' do
    let(:endpoint) { "/api_manage/v1/en/properties/#{property.id}/spp_publish" }

    it 'authenticates successfully with a valid API key' do
      post endpoint,
           headers: {
             'HTTP_HOST' => "#{website.subdomain}.localhost",
             'X-API-Key' => api_key
           },
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('published')
    end

    it 'returns 401 with an invalid API key' do
      post endpoint,
           headers: {
             'HTTP_HOST' => "#{website.subdomain}.localhost",
             'X-API-Key' => 'invalid-key'
           },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 without any API key' do
      post endpoint,
           headers: {
             'HTTP_HOST' => "#{website.subdomain}.localhost"
           },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 when integration is disabled' do
      integration.update!(enabled: false)

      post endpoint,
           headers: {
             'HTTP_HOST' => "#{website.subdomain}.localhost",
             'X-API-Key' => api_key
           },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'updates last_used_at on successful authentication' do
      expect(integration.last_used_at).to be_nil

      post endpoint,
           headers: {
             'HTTP_HOST' => "#{website.subdomain}.localhost",
             'X-API-Key' => api_key
           },
           as: :json

      integration.reload
      expect(integration.last_used_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe 'API key is scoped to the correct website' do
    let!(:other_website) { create(:pwb_website) }
    let!(:other_property) { create(:pwb_realty_asset, website: other_website) }

    it 'cannot use one website API key to access another website' do
      post "/api_manage/v1/en/properties/#{other_property.id}/spp_publish",
           headers: {
             'HTTP_HOST' => "#{other_website.subdomain}.localhost",
             'X-API-Key' => api_key
           },
           as: :json

      # API key belongs to `website`, not `other_website`, so auth fails
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
