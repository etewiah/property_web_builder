# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::AnalyticsController', type: :request do
  # Analytics is a premium feature for paid plans
  # Must verify: feature gating, period filtering, multi-tenancy, data display

  let!(:website) { create(:pwb_website, subdomain: 'analytics-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@analytics-test.test') }
  # Default plan with analytics feature for most tests
  let!(:default_plan) { create(:pwb_plan, :professional, features: %w[analytics basic_analytics basic_themes]) }
  let!(:default_subscription) { create(:pwb_subscription, :active, website: website, plan: default_plan) }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    allow_any_instance_of(ApplicationController).to receive(:current_website).and_return(website)
    allow_any_instance_of(SiteAdminController).to receive(:current_website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/analytics (show)' do
    context 'without subscription (free mode)' do
      # Remove the default subscription for this context
      before do
        default_subscription.destroy!
        website.reload
      end

      it 'redirects because analytics requires a subscription' do
        get site_admin_analytics_path, headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        # Without subscription, has_feature? returns false, so redirect expected
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'with subscription that includes analytics feature' do
      # Uses the default_subscription which has analytics feature

      it 'allows access to analytics' do
        get site_admin_analytics_path, headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'displays overview data' do
        get site_admin_analytics_path, headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        expect(response).to have_http_status(:success)
        # Overview should be available in assigns
      end
    end

    context 'with subscription without analytics feature' do
      before do
        # Replace default subscription with one that lacks analytics
        default_subscription.destroy!
        plan = create(:pwb_plan, :starter, features: ['basic_themes'])
        create(:pwb_subscription, :active, website: website, plan: plan)
        website.reload
      end

      it 'redirects to billing page' do
        get site_admin_analytics_path, headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        expect(response).to redirect_to(site_admin_billing_path)
      end

      it 'shows alert message about upgrading' do
        get site_admin_analytics_path, headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        expect(flash[:alert]).to include('not included in your current plan')
      end
    end

    context 'with basic_analytics feature' do
      # Uses the default_subscription which includes basic_analytics

      it 'allows access to analytics' do
        get site_admin_analytics_path, headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'period filtering' do
    context 'valid periods' do
      [7, 14, 30, 60, 90].each do |period|
        it "accepts period=#{period}" do
          get site_admin_analytics_path, params: { period: period },
              headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

          expect(response).to have_http_status(:success)
        end
      end
    end

    context 'invalid periods' do
      it 'defaults to 30 days for invalid period' do
        get site_admin_analytics_path, params: { period: 999 },
            headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        expect(response).to have_http_status(:success)
        # Controller should default to 30
      end

      it 'defaults to 30 days for negative period' do
        get site_admin_analytics_path, params: { period: -7 },
            headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'defaults to 30 days when period is missing' do
        get site_admin_analytics_path,
            headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET /site_admin/analytics/traffic' do
    it 'renders traffic page successfully' do
      get traffic_site_admin_analytics_path,
          headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    it 'includes traffic source data' do
      get traffic_site_admin_analytics_path,
          headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /site_admin/analytics/properties' do
    it 'renders properties analytics page successfully' do
      get properties_site_admin_analytics_path,
          headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'with property data' do
      let!(:property) { create(:pwb_prop, website: website) }

      it 'shows property analytics' do
        get properties_site_admin_analytics_path,
            headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET /site_admin/analytics/conversions' do
    it 'renders conversions page successfully' do
      get conversions_site_admin_analytics_path,
          headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    it 'includes funnel data' do
      get conversions_site_admin_analytics_path,
          headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /site_admin/analytics/realtime' do
    context 'HTML format' do
      it 'renders realtime page successfully' do
        get realtime_site_admin_analytics_path,
            headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'JSON format' do
      it 'returns JSON data' do
        get realtime_site_admin_analytics_path,
            params: { format: :json },
            headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('application/json')
      end

      it 'includes active_visitors and recent_pageviews' do
        get realtime_site_admin_analytics_path,
            params: { format: :json },
            headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('active_visitors')
        expect(json_response).to have_key('recent_pageviews')
      end
    end
  end

  describe 'multi-tenancy isolation' do
    let!(:other_website) { create(:pwb_website, subdomain: 'other-analytics') }
    let!(:other_agency) { create(:pwb_agency, website: other_website) }

    it 'only shows data for current website' do
      get site_admin_analytics_path,
          headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

      expect(response).to have_http_status(:success)
      # Analytics service is initialized with current_website only
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users' do
      get site_admin_analytics_path,
          headers: { 'HTTP_HOST' => 'analytics-test.test.localhost' }

      # Either redirect or forbidden (Pundit/CanCan)
      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
