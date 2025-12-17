# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site Admin Website Settings', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'settings-test') }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@settings-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  describe 'GET /site_admin/website/settings/general' do
    it 'renders the general settings tab successfully' do
      get site_admin_website_settings_path(tab: 'general'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('General Settings')
      expect(response.body).to include('Company Display Name')
      expect(response.body).to include('Supported Languages')
    end
  end

  describe 'PATCH /site_admin/website/settings (general tab)' do
    it 'updates supported locales successfully' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'general',
              pwb_website: {
                company_display_name: 'Test Company',
                default_client_locale: 'en-UK',
                supported_locales: ['en-UK', 'es', 'fr', '']
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      website.reload
      # Should filter out empty strings
      expect(website.supported_locales).to include('en-UK', 'es', 'fr')
    end

    it 'handles empty supported locales array' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'general',
              pwb_website: {
                company_display_name: 'Test Company',
                supported_locales: ['']
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'GET /site_admin/website/settings/appearance' do
    it 'renders the appearance settings tab successfully' do
      get site_admin_website_settings_path(tab: 'appearance'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Appearance Settings')
      expect(response.body).to include('Theme')
    end
  end

  describe 'GET /site_admin/website/settings/navigation' do
    it 'renders the navigation settings tab successfully' do
      get site_admin_website_settings_path(tab: 'navigation'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Navigation Settings')
    end
  end

  describe 'GET /site_admin/website/settings/notifications' do
    it 'renders the notifications settings tab successfully' do
      get site_admin_website_settings_path(tab: 'notifications'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Push Notifications')
    end
  end
end
