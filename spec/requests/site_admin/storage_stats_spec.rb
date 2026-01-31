# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::StorageStatsController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'storage-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@storage-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/storage_stats (show)' do
    it 'renders the storage stats page successfully' do
      get site_admin_storage_stats_path, headers: { 'HTTP_HOST' => 'storage-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    it 'provides storage statistics' do
      get site_admin_storage_stats_path, headers: { 'HTTP_HOST' => 'storage-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'with some storage used' do
      before do
        # Create media to populate ActiveStorage
        create(:pwb_media, website: website)
      end

      it 'shows storage stats' do
        get site_admin_storage_stats_path, headers: { 'HTTP_HOST' => 'storage-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /site_admin/storage_stats/cleanup' do
    it 'queues the cleanup job' do
      expect do
        post cleanup_site_admin_storage_stats_path,
             headers: { 'HTTP_HOST' => 'storage-test.test.localhost' }
      end.to have_enqueued_job(CleanupOrphanedBlobsJob)
    end

    it 'redirects with notice' do
      post cleanup_site_admin_storage_stats_path,
           headers: { 'HTTP_HOST' => 'storage-test.test.localhost' }

      expect(response).to redirect_to(site_admin_storage_stats_path)
      expect(flash[:notice]).to include('Cleanup job queued')
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users on show' do
      get site_admin_storage_stats_path,
          headers: { 'HTTP_HOST' => 'storage-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on cleanup' do
      post cleanup_site_admin_storage_stats_path,
           headers: { 'HTTP_HOST' => 'storage-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
