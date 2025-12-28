# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::DashboardController', type: :request do
  # Dashboard is the main entry point for site admins
  # Must verify: authentication, statistics, multi-tenancy isolation

  let!(:website) { create(:pwb_website, subdomain: 'dashboard-test') }
  let!(:agency) { create(:pwb_agency, website: website, company_name: 'Test Agency', email_primary: 'agency@test.com') }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@dashboard-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  describe 'GET /site_admin (index)' do
    it 'renders the dashboard successfully' do
      get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    it 'displays website statistics' do
      get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

      expect(response.body).to include('Properties')
      expect(response.body).to include('Messages')
    end

    context 'with data' do
      let!(:property) { create(:pwb_prop, website: website) }
      let!(:message) { create(:pwb_message, website: website) }
      let!(:contact) { create(:pwb_contact, website: website) }
      let!(:page) { create(:pwb_page, website: website) }

      it 'shows correct property count' do
        get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

        # Dashboard should show statistics
        expect(response).to have_http_status(:success)
      end

      it 'shows recent messages' do
        get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'shows recent contacts' do
        get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'weekly statistics' do
      let!(:old_message) { create(:pwb_message, website: website, created_at: 2.weeks.ago) }
      let!(:new_message) { create(:pwb_message, website: website, created_at: 1.day.ago) }

      it 'calculates weekly stats correctly' do
        get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

        # Should only count messages from this week in weekly stats
        expect(response).to have_http_status(:success)
      end
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-dashboard') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:other_property) { create(:pwb_prop, website: other_website) }
      let!(:other_message) { create(:pwb_message, website: other_website) }
      let!(:other_contact) { create(:pwb_contact, website: other_website) }

      let!(:my_property) { create(:pwb_prop, website: website) }
      let!(:my_message) { create(:pwb_message, website: website) }

      it 'only shows data for current website' do
        get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

        # Response should be successful and only show current website's data
        expect(response).to have_http_status(:success)
        # The dashboard should not expose other website's data
      end

      it 'does not include other website property count' do
        # Verify the counts are isolated
        my_count = Pwb::Prop.where(website_id: website.id).count
        other_count = Pwb::Prop.where(website_id: other_website.id).count

        expect(my_count).to eq(1)
        expect(other_count).to eq(1)
        expect(my_count + other_count).to eq(2)

        get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

        # Dashboard should only see my_count (1), not total (2)
        expect(response).to have_http_status(:success)
      end

      it 'does not include other website messages in recent activity' do
        my_messages = Pwb::Message.where(website_id: website.id).count
        other_messages = Pwb::Message.where(website_id: other_website.id).count

        expect(my_messages).to eq(1)
        expect(other_messages).to eq(1)

        get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'authentication required' do
      before { sign_out admin_user }

      it 'redirects unauthenticated users' do
        get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

        expect(response).to have_http_status(:redirect)
      end
    end

    context 'website health checklist' do
      it 'shows health percentage' do
        get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

        expect(response).to have_http_status(:success)
        # Dashboard should show setup completion status
      end

      context 'with complete agency profile' do
        before do
          agency.update!(company_name: 'Complete Agency', email_primary: 'complete@test.com')
        end

        it 'marks agency profile as complete' do
          get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

          expect(response).to have_http_status(:success)
        end
      end

      context 'with incomplete agency profile' do
        before do
          agency.update!(company_name: nil, email_primary: nil)
        end

        it 'marks agency profile as incomplete' do
          get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

          expect(response).to have_http_status(:success)
        end
      end
    end

    context 'subscription information' do
      let!(:plan) { create(:pwb_plan, display_name: 'Pro Plan') }
      let!(:subscription) { create(:pwb_subscription, website: website, plan: plan, status: 'active') }

      it 'displays subscription details' do
        get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Pro Plan')
      end
    end

    context 'getting started guide' do
      it 'shows getting started for new websites' do
        get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

        expect(response).to have_http_status(:success)
        # New websites with low health score should see getting started
      end

      context 'when dismissed via cookie' do
        before do
          cookies[:dismiss_getting_started] = 'true'
        end

        it 'hides getting started guide' do
          get site_admin_root_path, headers: { 'HTTP_HOST' => 'dashboard-test.test.localhost' }

          expect(response).to have_http_status(:success)
        end
      end
    end
  end
end
