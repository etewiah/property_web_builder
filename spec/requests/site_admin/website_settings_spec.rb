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
      # Should filter out empty strings from hidden form field
      expect(website.supported_locales).to eq(['en-UK', 'es', 'fr'])
      expect(website.supported_locales).not_to include('')
    end

    it 'handles array with only blank entries by saving empty array' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'general',
              pwb_website: {
                company_display_name: 'Test Company',
                supported_locales: ['']
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      # Blank entries are filtered out, resulting in empty array (which is allowed)
      expect(response).to have_http_status(:redirect)
      website.reload
      expect(website.supported_locales).to eq([])
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

  describe 'GET /site_admin/website/settings/social' do
    it 'renders the social settings tab successfully' do
      get site_admin_website_settings_path(tab: 'social'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Social Media Links')
    end

    it 'displays all 6 social media platforms' do
      get site_admin_website_settings_path(tab: 'social'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response.body).to include('Facebook')
      expect(response.body).to include('Instagram')
      expect(response.body).to include('Linkedin')
      expect(response.body).to include('Youtube')
      expect(response.body).to include('Twitter')
      expect(response.body).to include('Whatsapp')
    end

    it 'shows existing social media link URLs' do
      website.links.create!(
        slug: 'social_media_facebook',
        link_url: 'https://facebook.com/existingpage',
        placement: :social_media
      )

      get site_admin_website_settings_path(tab: 'social'),
          headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response.body).to include('https://facebook.com/existingpage')
    end
  end

  describe 'PATCH /site_admin/website/settings (social tab)' do
    it 'creates new social media links' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'social',
              social_links: {
                facebook: 'https://facebook.com/newpage',
                instagram: 'https://instagram.com/newhandle'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(site_admin_website_settings_tab_path('social'))

      facebook_link = website.links.find_by(slug: 'social_media_facebook')
      expect(facebook_link.link_url).to eq('https://facebook.com/newpage')

      instagram_link = website.links.find_by(slug: 'social_media_instagram')
      expect(instagram_link.link_url).to eq('https://instagram.com/newhandle')
    end

    it 'updates existing social media links' do
      website.links.create!(
        slug: 'social_media_facebook',
        link_url: 'https://facebook.com/oldpage',
        placement: :social_media
      )

      patch site_admin_website_settings_path,
            params: {
              tab: 'social',
              social_links: {
                facebook: 'https://facebook.com/updatedpage'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(response).to have_http_status(:redirect)

      facebook_link = website.links.find_by(slug: 'social_media_facebook')
      expect(facebook_link.link_url).to eq('https://facebook.com/updatedpage')
    end

    it 'sets link visibility based on URL presence' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'social',
              social_links: {
                facebook: 'https://facebook.com/page',
                twitter: ''
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      facebook_link = website.links.find_by(slug: 'social_media_facebook')
      twitter_link = website.links.find_by(slug: 'social_media_twitter')

      expect(facebook_link.visible).to be true
      expect(twitter_link.visible).to be false
    end

    it 'shows success notice after update' do
      patch site_admin_website_settings_path,
            params: {
              tab: 'social',
              social_links: {
                whatsapp: 'https://wa.me/1234567890'
              }
            },
            headers: { 'HTTP_HOST' => 'settings-test.e2e.localhost' }

      expect(flash[:notice]).to eq('Social media links updated successfully')
    end
  end
end
