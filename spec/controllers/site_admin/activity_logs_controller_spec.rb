# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::ActivityLogsController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-activity') }
  let(:other_website) { create(:pwb_website, subdomain: 'other-activity') }
  let(:user) { create(:pwb_user, :admin, website: website) }
  let(:other_user) { create(:pwb_user, website: website, email: 'other@test.com') }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user, scope: :user
    allow(Pwb::Current).to receive(:website).and_return(website)
    allow(controller).to receive(:current_website).and_return(website)
  end

  describe 'GET #index' do
    context 'with activity logs' do
      before do
        # Clean up any existing logs for this website to ensure test isolation
        Pwb::AuthAuditLog.where(website: website).delete_all
      end

      let!(:log1) { create(:pwb_auth_audit_log, :login_success, website: website, user: user, created_at: 1.hour.ago) }
      let!(:log2) { create(:pwb_auth_audit_log, :login_failure, website: website, user: user, created_at: 2.hours.ago) }
      let!(:log3) { create(:pwb_auth_audit_log, :logout, website: website, user: user, created_at: 3.hours.ago) }
      let!(:other_log) { create(:pwb_auth_audit_log, :login_success, website: other_website) }

      it 'returns success' do
        get :index
        expect(response).to have_http_status(:success)
      end

      it 'assigns logs for current website only' do
        get :index
        logs = assigns(:logs)
        expect(logs).to include(log1, log2, log3)
        expect(logs).not_to include(other_log)
      end

      it 'orders logs by most recent first' do
        get :index
        logs = assigns(:logs).to_a
        # Check that logs are ordered by created_at desc
        expect(logs.first.created_at).to be >= logs.last.created_at
      end

      it 'assigns event types for filtering' do
        get :index
        expect(assigns(:event_types)).to eq(Pwb::AuthAuditLog::EVENT_TYPES)
      end

      it 'assigns users for filtering' do
        get :index
        users = assigns(:users)
        expect(users).to include(user)
      end

      it 'assigns stats' do
        get :index
        stats = assigns(:stats)
        expect(stats).to include(:total_today, :logins_today, :failures_today, :unique_ips_today)
      end
    end

    context 'filtering by event type' do
      let!(:login_log) { create(:pwb_auth_audit_log, :login_success, website: website) }
      let!(:logout_log) { create(:pwb_auth_audit_log, :logout, website: website) }
      let!(:failure_log) { create(:pwb_auth_audit_log, :login_failure, website: website) }

      it 'filters by login_success event type' do
        get :index, params: { event_type: 'login_success' }
        logs = assigns(:logs)
        expect(logs).to include(login_log)
        expect(logs).not_to include(logout_log, failure_log)
      end

      it 'filters by login_failure event type' do
        get :index, params: { event_type: 'login_failure' }
        logs = assigns(:logs)
        expect(logs).to include(failure_log)
        expect(logs).not_to include(login_log, logout_log)
      end

      it 'filters by logout event type' do
        get :index, params: { event_type: 'logout' }
        logs = assigns(:logs)
        expect(logs).to include(logout_log)
        expect(logs).not_to include(login_log, failure_log)
      end
    end

    context 'filtering by user' do
      let!(:user_log) { create(:pwb_auth_audit_log, website: website, user: user) }
      let!(:other_user_log) { create(:pwb_auth_audit_log, website: website, user: other_user) }

      it 'filters by user_id' do
        get :index, params: { user_id: user.id }
        logs = assigns(:logs)
        expect(logs).to include(user_log)
        expect(logs).not_to include(other_user_log)
      end
    end

    context 'filtering by date range' do
      let!(:recent_log) { create(:pwb_auth_audit_log, website: website, created_at: 30.minutes.ago) }
      let!(:old_log) { create(:pwb_auth_audit_log, website: website, created_at: 2.days.ago) }

      it 'filters by last hour' do
        get :index, params: { since: '1h' }
        logs = assigns(:logs)
        expect(logs).to include(recent_log)
        expect(logs).not_to include(old_log)
      end

      it 'filters by last 24 hours' do
        get :index, params: { since: '24h' }
        logs = assigns(:logs)
        expect(logs).to include(recent_log)
        expect(logs).not_to include(old_log)
      end

      it 'filters by last 7 days' do
        get :index, params: { since: '7d' }
        logs = assigns(:logs)
        expect(logs).to include(recent_log, old_log)
      end

      it 'ignores invalid since parameter' do
        get :index, params: { since: 'invalid' }
        logs = assigns(:logs)
        expect(logs).to include(recent_log, old_log)
      end
    end

    context 'stats calculation' do
      before do
        # Clean up any existing logs for this website to ensure test isolation
        Pwb::AuthAuditLog.where(website: website).delete_all

        # Create logs for today (using user and website from test context)
        3.times { create(:pwb_auth_audit_log, :login_success, :today, website: website, user: user) }
        2.times { create(:pwb_auth_audit_log, :login_failure, :today, website: website, user: user) }
        # Create logs for yesterday (should not be in today stats)
        5.times { create(:pwb_auth_audit_log, :login_success, :yesterday, website: website, user: user) }
      end

      it 'calculates total today correctly' do
        get :index
        stats = assigns(:stats)
        expect(stats[:total_today]).to eq(5) # 3 successes + 2 failures today
      end

      it 'calculates logins today correctly' do
        get :index
        stats = assigns(:stats)
        expect(stats[:logins_today]).to eq(3)
      end

      it 'calculates failures today correctly' do
        get :index
        stats = assigns(:stats)
        expect(stats[:failures_today]).to eq(2)
      end
    end

    context 'with pagination' do
      before do
        create_list(:pwb_auth_audit_log, 60, website: website)
      end

      it 'paginates results' do
        get :index
        expect(assigns(:pagy)).to be_present
        expect(assigns(:logs).count).to be <= 50
      end
    end
  end

  describe 'GET #show' do
    let!(:log) { create(:pwb_auth_audit_log, :login_success, website: website, user: user) }
    let!(:other_log) { create(:pwb_auth_audit_log, :login_success, website: other_website) }

    it 'returns success for own website log' do
      get :show, params: { id: log.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the log' do
      get :show, params: { id: log.id }
      expect(assigns(:log)).to eq(log)
    end

    it 'returns 404 for other website log' do
      get :show, params: { id: other_log.id }
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-existent log' do
      get :show, params: { id: 999999 }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'multi-tenant isolation' do
    before do
      # Clean up existing logs for isolation
      Pwb::AuthAuditLog.where(website: website).delete_all
      Pwb::AuthAuditLog.where(website: other_website).delete_all
    end

    let!(:own_logs) { create_list(:pwb_auth_audit_log, 3, website: website) }
    let!(:other_logs) { create_list(:pwb_auth_audit_log, 5, website: other_website) }

    it 'only shows logs from current website in index' do
      get :index
      logs = assigns(:logs)
      expect(logs.pluck(:website_id).uniq).to eq([website.id])
    end

    it 'cannot access logs from other website in show' do
      other_log = other_logs.first
      get :show, params: { id: other_log.id }
      expect(response).to have_http_status(:not_found)
    end

    it 'stats only count current website events' do
      # Clean up again for this specific test
      Pwb::AuthAuditLog.where(website: website).delete_all
      Pwb::AuthAuditLog.where(website: other_website).delete_all

      create_list(:pwb_auth_audit_log, 5, :login_success, :today, website: website)
      create_list(:pwb_auth_audit_log, 10, :login_success, :today, website: other_website)

      get :index
      stats = assigns(:stats)
      expect(stats[:logins_today]).to eq(5)
    end
  end

  describe 'authentication' do
    context 'when user is not signed in' do
      before { sign_out :user }

      it 'denies access to index' do
        get :index
        expect(response.status).to eq(302).or eq(403)
      end

      it 'denies access to show' do
        log = create(:pwb_auth_audit_log, website: website)
        get :show, params: { id: log.id }
        expect(response.status).to eq(302).or eq(403)
      end
    end
  end
end
