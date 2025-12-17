# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::AnalyticsController, type: :controller do
  let(:website) { create(:website) }
  let(:user) { create(:user) }
  let(:plan_with_analytics) { create(:plan, features: ['analytics']) }
  let(:plan_without_analytics) { create(:plan, features: ['basic_themes']) }

  before do
    # Set up tenant context
    allow(Pwb::Current).to receive(:website).and_return(website)
    allow(controller).to receive(:current_website).and_return(website)
    sign_in user
  end

  describe 'GET #show' do
    context 'when analytics feature is enabled' do
      before do
        subscription = create(:subscription, website: website, plan: plan_with_analytics)
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
        expect(assigns(:visits_chart)).to be_present
        expect(assigns(:traffic_sources)).to be_present
        expect(assigns(:device_breakdown)).to be_present
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
        subscription = create(:subscription, website: website, plan: plan_without_analytics)
        allow(website).to receive(:subscription).and_return(subscription)
      end

      it 'redirects to dashboard' do
        get :show
        expect(response).to redirect_to(site_admin_dashboard_path)
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
      subscription = create(:subscription, website: website, plan: plan_with_analytics)
      allow(website).to receive(:subscription).and_return(subscription)
    end

    it 'returns success' do
      get :traffic
      expect(response).to have_http_status(:success)
    end

    it 'assigns traffic data' do
      get :traffic
      expect(assigns(:visits_by_day)).to be_present
      expect(assigns(:traffic_sources)).to be_present
      expect(assigns(:geographic)).to be_present
    end
  end

  describe 'GET #properties' do
    before do
      subscription = create(:subscription, website: website, plan: plan_with_analytics)
      allow(website).to receive(:subscription).and_return(subscription)
    end

    it 'returns success' do
      get :properties
      expect(response).to have_http_status(:success)
    end

    it 'assigns property analytics data' do
      get :properties
      expect(assigns(:top_properties)).to be_present
      expect(assigns(:property_views_by_day)).to be_present
      expect(assigns(:top_searches)).to be_present
    end
  end

  describe 'GET #conversions' do
    before do
      subscription = create(:subscription, website: website, plan: plan_with_analytics)
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
      subscription = create(:subscription, website: website, plan: plan_with_analytics)
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
