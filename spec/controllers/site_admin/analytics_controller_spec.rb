# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::AnalyticsController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-analytics') }
  let(:user) { create(:pwb_user, :admin, website: website) }
  let(:plan_with_analytics) { create(:pwb_plan, features: ['analytics']) }
  let(:plan_without_analytics) { create(:pwb_plan, features: ['basic_themes']) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user, scope: :user
    allow(Pwb::Current).to receive(:website).and_return(website)
    allow(controller).to receive(:current_website).and_return(website)
  end

  describe 'GET #show' do
    context 'when analytics feature is enabled' do
      before do
        subscription = create(:pwb_subscription, website: website, plan: plan_with_analytics)
        allow(website).to receive(:subscription).and_return(subscription)
      end

      it 'returns success' do
        get :show
        expect(response).to have_http_status(:success)
      end

      it 'assigns analytics overview' do
        get :show
        expect(assigns(:overview)).to be_present
        expect(assigns(:overview)).to include(:total_visits, :unique_visitors, :property_views)
      end

      it 'assigns chart data' do
        get :show
        # These may be empty hashes if no analytics data exists yet
        expect(assigns(:visits_chart)).not_to be_nil
        expect(assigns(:traffic_sources)).not_to be_nil
        expect(assigns(:device_breakdown)).not_to be_nil
      end

      context 'with period parameter' do
        it 'uses the specified period' do
          get :show, params: { period: 7 }
          expect(assigns(:period)).to eq(7)
        end

        it 'defaults to 30 days for invalid periods' do
          get :show, params: { period: 999 }
          expect(assigns(:period)).to eq(30)
        end
      end
    end

    context 'when analytics feature is not enabled' do
      before do
        subscription = create(:pwb_subscription, website: website, plan: plan_without_analytics)
        allow(website).to receive(:subscription).and_return(subscription)
      end

      it 'redirects to dashboard' do
        get :show
        expect(response).to redirect_to(site_admin_root_path)
      end

      it 'sets flash alert' do
        get :show
        expect(flash[:alert]).to include('Analytics is available on paid plans')
      end
    end

    context 'when no subscription exists' do
      before do
        allow(website).to receive(:subscription).and_return(nil)
      end

      it 'allows access (free mode)' do
        get :show
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET #traffic' do
    before do
      subscription = create(:pwb_subscription, website: website, plan: plan_with_analytics)
      allow(website).to receive(:subscription).and_return(subscription)
    end

    it 'returns success' do
      get :traffic
      expect(response).to have_http_status(:success)
    end

    it 'assigns traffic data' do
      get :traffic
      # These may be empty hashes if no analytics data exists yet
      expect(assigns(:visits_by_day)).not_to be_nil
      expect(assigns(:traffic_sources)).not_to be_nil
      expect(assigns(:geographic)).not_to be_nil
    end
  end

  describe 'GET #properties' do
    before do
      subscription = create(:pwb_subscription, website: website, plan: plan_with_analytics)
      allow(website).to receive(:subscription).and_return(subscription)
    end

    it 'returns success' do
      get :properties
      expect(response).to have_http_status(:success)
    end

    it 'assigns property analytics data' do
      get :properties
      # These may be empty hashes if no analytics data exists yet
      expect(assigns(:top_properties)).not_to be_nil
      expect(assigns(:property_views_by_day)).not_to be_nil
      expect(assigns(:top_searches)).not_to be_nil
    end
  end

  describe 'GET #conversions' do
    before do
      subscription = create(:pwb_subscription, website: website, plan: plan_with_analytics)
      allow(website).to receive(:subscription).and_return(subscription)
    end

    it 'returns success' do
      get :conversions
      expect(response).to have_http_status(:success)
    end

    it 'assigns funnel data' do
      get :conversions
      expect(assigns(:funnel)).to include(:visits, :property_views, :inquiries)
      expect(assigns(:conversion_rates)).to be_present
    end
  end

  describe 'GET #realtime' do
    before do
      subscription = create(:pwb_subscription, website: website, plan: plan_with_analytics)
      allow(website).to receive(:subscription).and_return(subscription)
    end

    it 'returns success for HTML format' do
      get :realtime
      expect(response).to have_http_status(:success)
    end

    it 'returns JSON for JSON format' do
      get :realtime, format: :json
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('application/json')

      json = JSON.parse(response.body)
      expect(json).to include('active_visitors', 'recent_pageviews')
    end
  end
end
