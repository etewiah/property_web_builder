# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site Admin Navigation', type: :request do
  let(:website) { create(:website) }
  let(:admin_user) { create(:user, :admin, website: website) }

  before do
    sign_in admin_user
    allow_any_instance_of(ApplicationController).to receive(:current_website).and_return(website)
    allow_any_instance_of(SiteAdminController).to receive(:current_website).and_return(website)
  end

  describe 'navigation structure' do
    it 'renders the dashboard link' do
      get site_admin_root_path
      expect(response.body).to include('Dashboard')
    end

    it 'renders the Listings section' do
      get site_admin_root_path
      expect(response.body).to include('Listings')
      expect(response.body).to include(site_admin_props_path)
      expect(response.body).to include(site_admin_property_import_export_path)
      expect(response.body).to include(site_admin_properties_settings_path)
    end

    it 'renders the Leads & Messages section' do
      get site_admin_root_path
      expect(response.body).to include('Leads &amp; Messages').or include('Leads & Messages')
      expect(response.body).to include(site_admin_inbox_index_path)
      expect(response.body).to include(site_admin_contacts_path)
      expect(response.body).to include(site_admin_messages_path)
      expect(response.body).to include(site_admin_email_templates_path)
    end

    it 'renders the Site Design section' do
      get site_admin_root_path
      expect(response.body).to include('Site Design')
      expect(response.body).to include(site_admin_pages_path)
      expect(response.body).to include(site_admin_media_library_index_path)
    end

    it 'renders the Insights section' do
      get site_admin_root_path
      expect(response.body).to include('Insights')
    end

    it 'renders the Settings section' do
      get site_admin_root_path
      expect(response.body).to include('Settings')
      expect(response.body).to include(site_admin_users_path)
    end
  end

  describe 'navigation accessibility' do
    it 'includes tour IDs for guided tour' do
      get site_admin_root_path
      expect(response.body).to include('id="tour-dashboard"')
      expect(response.body).to include('id="tour-listings"')
      expect(response.body).to include('id="tour-inbox"')
    end
  end

  describe 'navigation links are clickable' do
    it 'all navigation paths are present in response' do
      get site_admin_root_path

      # Core paths that must appear in navigation
      [
        site_admin_props_path,
        site_admin_pages_path,
        site_admin_inbox_index_path,
        site_admin_contacts_path,
        site_admin_users_path
      ].each do |path|
        expect(response.body).to include(path),
          "Expected navigation to include link to #{path}"
      end
    end
  end
end
