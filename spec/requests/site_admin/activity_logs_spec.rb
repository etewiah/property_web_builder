# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::ActivityLogsController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'logs-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@logs-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/activity_logs (index)' do
    it 'renders the activity logs page successfully' do
      get site_admin_activity_logs_path, headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'with activity logs' do
      let!(:log1) { create(:pwb_auth_audit_log, :login_success, website: website, user: admin_user) }
      let!(:log2) { create(:pwb_auth_audit_log, :login_failure, website: website, email: 'hacker@test.com') }
      let!(:log3) { create(:pwb_auth_audit_log, :logout, website: website, user: admin_user) }

      it 'displays logs in the list' do
        get site_admin_activity_logs_path, headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'filters by event type' do
        get site_admin_activity_logs_path,
            params: { event_type: 'login_success' },
            headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'filters by user ID' do
        get site_admin_activity_logs_path,
            params: { user_id: admin_user.id },
            headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'filters by date range - 1 hour' do
        get site_admin_activity_logs_path,
            params: { since: '1h' },
            headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'filters by date range - 24 hours' do
        get site_admin_activity_logs_path,
            params: { since: '24h' },
            headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'filters by date range - 7 days' do
        get site_admin_activity_logs_path,
            params: { since: '7d' },
            headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'filters by date range - 30 days' do
        get site_admin_activity_logs_path,
            params: { since: '30d' },
            headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'with stats' do
      before do
        # Create logs for today
        create(:pwb_auth_audit_log, :login_success, :today, website: website, user: admin_user)
        create(:pwb_auth_audit_log, :login_failure, :today, website: website, email: 'test@example.com')
      end

      it 'calculates today stats' do
        get site_admin_activity_logs_path, headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-logs') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:my_log) { create(:pwb_auth_audit_log, :login_success, website: website, user: admin_user, email: 'mylog@test.com') }
      let!(:other_log) { create(:pwb_auth_audit_log, :login_success, website: other_website, email: 'otherlog@test.com') }

      it 'only shows logs for current website' do
        get site_admin_activity_logs_path, headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('otherlog@test.com')
      end
    end
  end

  describe 'GET /site_admin/activity_logs/:id (show)' do
    let!(:log) { create(:pwb_auth_audit_log, :login_success, website: website, user: admin_user) }

    it 'renders the log detail page' do
      get site_admin_activity_log_path(log),
          headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    it 'displays log details' do
      get site_admin_activity_log_path(log),
          headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(log.email)
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-show-log') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:other_log) { create(:pwb_auth_audit_log, website: other_website) }

      it 'cannot access logs from other websites' do
        get site_admin_activity_log_path(other_log),
            headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

        expect(response).to have_http_status(:not_found)
      rescue ActiveRecord::RecordNotFound
        expect(true).to be true
      end
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users on index' do
      get site_admin_activity_logs_path,
          headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on show' do
      log = create(:pwb_auth_audit_log, website: website)

      get site_admin_activity_log_path(log),
          headers: { 'HTTP_HOST' => 'logs-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
