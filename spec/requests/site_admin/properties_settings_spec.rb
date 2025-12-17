# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site Admin Properties Settings', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'props-settings-test', supported_locales: ['en-UK', 'es']) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@props-settings.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website

    # Create tenant-specific field keys
    PwbTenant::FieldKey.create!(
      global_key: 'types.apartment',
      tag: 'property-types',
      visible: true
    ).tap do |fk|
      Mobility.with_locale(:en) { fk.label = 'Apartment' }
      Mobility.with_locale(:es) { fk.label = 'Apartamento' }
      fk.save!
    end

    PwbTenant::FieldKey.create!(
      global_key: 'types.villa',
      tag: 'property-types',
      visible: true
    ).tap do |fk|
      Mobility.with_locale(:en) { fk.label = 'Villa' }
      fk.save!
    end
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/properties/settings' do
    it 'renders the settings index page successfully' do
      get site_admin_properties_settings_path,
          headers: { 'HTTP_HOST' => 'props-settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Property Field Keys')
      expect(response.body).to include('Property Types')
      expect(response.body).to include('Features')
    end
  end

  describe 'GET /site_admin/properties/settings/:category' do
    it 'renders property types category successfully' do
      get site_admin_properties_settings_category_path('property_types'),
          headers: { 'HTTP_HOST' => 'props-settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Property Types')
      expect(response.body).to include('Apartment')
    end

    it 'handles website with empty supported_locales' do
      website.update!(supported_locales: [''])

      get site_admin_properties_settings_category_path('property_types'),
          headers: { 'HTTP_HOST' => 'props-settings-test.e2e.localhost' }

      # Should not raise "undefined method 'downcase' for nil"
      expect(response).to have_http_status(:success)
    end

    it 'handles website with nil in supported_locales array' do
      # Simulate corrupted data
      website.update_column(:supported_locales, ['en-UK', nil, 'es'])

      get site_admin_properties_settings_category_path('property_types'),
          headers: { 'HTTP_HOST' => 'props-settings-test.e2e.localhost' }

      # Should not raise an error
      expect(response).to have_http_status(:success)
    end

    it 'shows translations for each supported locale' do
      get site_admin_properties_settings_category_path('property_types'),
          headers: { 'HTTP_HOST' => 'props-settings-test.e2e.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('English')
      expect(response.body).to include('Spanish')
    end

    it 'returns invalid category error for unknown category' do
      get site_admin_properties_settings_category_path('invalid_category'),
          headers: { 'HTTP_HOST' => 'props-settings-test.e2e.localhost' }

      expect(response).to redirect_to(site_admin_root_path)
    end
  end

  describe 'POST /site_admin/properties/settings/:category' do
    it 'creates a new field key' do
      initial_count = Pwb::FieldKey.where(pwb_website_id: website.id).count

      post site_admin_properties_settings_category_path('property_types'),
           params: {
             field_key: {
               visible: true,
               translations: { 'en' => 'Penthouse', 'es' => 'Atico' }
             }
           },
           headers: { 'HTTP_HOST' => 'props-settings-test.e2e.localhost' }

      expect(response).to redirect_to(site_admin_properties_settings_category_path('property_types'))
      expect(Pwb::FieldKey.where(pwb_website_id: website.id).count).to eq(initial_count + 1)
    end
  end
end
