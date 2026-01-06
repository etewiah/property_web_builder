# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::BillingController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-billing') }
  let(:other_website) { create(:pwb_website, subdomain: 'other-billing') }
  let(:user) { create(:pwb_user, :admin, website: website) }
  let(:plan) { create(:pwb_plan, :professional, property_limit: 100, user_limit: 10) }
  let(:free_plan) { create(:pwb_plan, :free) }
  let(:unlimited_plan) { create(:pwb_plan, :enterprise, :unlimited_properties, :unlimited_users) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user, scope: :user
    allow(Pwb::Current).to receive(:website).and_return(website)
    allow(controller).to receive(:current_website).and_return(website)
  end

  describe 'GET #show' do
    context 'with an active subscription' do
      let!(:subscription) { create(:pwb_subscription, :active, website: website, plan: plan) }

      it 'returns success' do
        get :show
        expect(response).to have_http_status(:success)
      end

      it 'assigns the subscription' do
        get :show
        expect(assigns(:subscription)).to eq(subscription)
      end

      it 'assigns the plan' do
        get :show
        expect(assigns(:plan)).to eq(plan)
      end

      it 'assigns usage data' do
        get :show
        usage = assigns(:usage)
        expect(usage).to be_a(Hash)
        expect(usage).to include(:properties, :users)
      end

      it 'calculates property usage correctly' do
        create_list(:pwb_realty_asset, 3, website: website)

        get :show

        usage = assigns(:usage)
        expect(usage[:properties][:current]).to eq(3)
        expect(usage[:properties][:limit]).to eq(100)
        expect(usage[:properties][:unlimited]).to be false
      end

      it 'calculates user usage correctly' do
        create_list(:pwb_user, 2, website: website)

        get :show

        usage = assigns(:usage)
        # Includes the signed-in admin user plus 2 more
        expect(usage[:users][:current]).to be >= 3
        expect(usage[:users][:limit]).to eq(10)
        expect(usage[:users][:unlimited]).to be false
      end
    end

    context 'with a trialing subscription' do
      let!(:subscription) { create(:pwb_subscription, :trialing, website: website, plan: plan) }

      it 'returns success' do
        get :show
        expect(response).to have_http_status(:success)
      end

      it 'assigns the trialing subscription' do
        get :show
        expect(assigns(:subscription).status).to eq('trialing')
      end
    end

    context 'with a canceled subscription' do
      let!(:subscription) { create(:pwb_subscription, :canceled, website: website, plan: plan) }

      it 'redirects to billing page' do
        get :show
        expect(response).to redirect_to(site_admin_billing_path)
      end


    end

    context 'with a past_due subscription' do
      let!(:subscription) { create(:pwb_subscription, :past_due, website: website, plan: plan) }

      it 'returns success' do
        get :show
        expect(response).to have_http_status(:success)
      end

      it 'assigns the past_due subscription' do
        get :show
        expect(assigns(:subscription).status).to eq('past_due')
      end
    end

    context 'with an unlimited plan' do
      let!(:subscription) { create(:pwb_subscription, :active, website: website, plan: unlimited_plan) }

      it 'shows unlimited properties' do
        get :show

        usage = assigns(:usage)
        expect(usage[:properties][:unlimited]).to be true
      end

      it 'shows unlimited users' do
        get :show

        usage = assigns(:usage)
        expect(usage[:users][:unlimited]).to be true
      end
    end

    context 'without a subscription' do
      it 'returns success' do
        get :show
        expect(response).to have_http_status(:success)
      end

      it 'assigns nil subscription' do
        get :show
        expect(assigns(:subscription)).to be_nil
      end

      it 'assigns nil plan' do
        get :show
        expect(assigns(:plan)).to be_nil
      end

      it 'still calculates usage' do
        get :show
        usage = assigns(:usage)
        expect(usage).to be_a(Hash)
        expect(usage[:properties][:current]).to be_a(Integer)
      end
    end

    context 'subscription canceling at period end' do
      let!(:subscription) do
        create(:pwb_subscription, :active, :cancel_at_period_end, website: website, plan: plan)
      end

      it 'returns success' do
        get :show
        expect(response).to have_http_status(:success)
      end

      it 'shows cancel_at_period_end flag' do
        get :show
        expect(assigns(:subscription).cancel_at_period_end?).to be true
      end
    end
  end

  describe 'multi-tenant isolation' do
    let!(:subscription) { create(:pwb_subscription, :active, website: website, plan: plan) }
    let!(:other_subscription) { create(:pwb_subscription, :active, website: other_website, plan: unlimited_plan) }

    it 'only shows current website subscription' do
      get :show
      expect(assigns(:subscription)).to eq(subscription)
      expect(assigns(:subscription)).not_to eq(other_subscription)
    end

    it 'only counts current website properties in usage' do
      # Clean up any existing properties
      Pwb::RealtyAsset.where(website: website).delete_all
      Pwb::RealtyAsset.where(website: other_website).delete_all

      # Create properties directly in database (to bypass plan limit validations)
      5.times do |i|
        Pwb::RealtyAsset.insert({ website_id: website.id, reference: "test-own-#{i}", created_at: Time.current, updated_at: Time.current })
      end
      10.times do |i|
        Pwb::RealtyAsset.insert({ website_id: other_website.id, reference: "test-other-#{i}", created_at: Time.current, updated_at: Time.current })
      end

      get :show

      usage = assigns(:usage)
      expect(usage[:properties][:current]).to eq(5)
    end

    it 'only counts current website users in usage' do
      # Count existing users for current website (including the signed-in admin)
      existing_user_count = website.users.count

      create_list(:pwb_user, 3, website: website)
      create_list(:pwb_user, 7, website: other_website)

      get :show

      usage = assigns(:usage)
      # existing users + 3 new users
      expect(usage[:users][:current]).to eq(existing_user_count + 3)
    end
  end

  describe 'authentication' do
    context 'when user is not signed in' do
      before { sign_out :user }

      it 'denies access' do
        get :show
        expect(response.status).to eq(302).or eq(403)
      end
    end
  end
end
