# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantAdmin::SubscriptionsController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:admin_user) { create(:pwb_user, email: 'admin@example.com', website: website) }
  let(:plan) { create(:pwb_plan) }
  let(:subscription) { create(:pwb_subscription, plan: plan) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
    sign_in admin_user, scope: :user
  end

  describe 'GET #index' do
    let!(:active_subscription) { create(:pwb_subscription, :active, plan: plan) }
    let!(:trialing_subscription) { create(:pwb_subscription, :trialing, plan: plan) }
    let!(:canceled_subscription) { create(:pwb_subscription, :canceled, plan: plan) }

    it 'returns a successful response' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns @subscriptions' do
      get :index
      expect(assigns(:subscriptions)).to be_present
    end

    it 'assigns @stats with subscription statistics' do
      get :index
      expect(assigns(:stats)).to include(:total, :active, :trialing, :past_due, :canceled)
    end

    it 'assigns @plans for filtering' do
      get :index
      expect(assigns(:plans)).to be_present
    end

    context 'with status filter' do
      it 'filters subscriptions by active status' do
        get :index, params: { status: 'active' }
        expect(assigns(:subscriptions)).to all(have_attributes(status: 'active'))
      end

      it 'filters subscriptions by trialing status' do
        get :index, params: { status: 'trialing' }
        expect(assigns(:subscriptions)).to all(have_attributes(status: 'trialing'))
      end

      it 'filters subscriptions by canceled status' do
        get :index, params: { status: 'canceled' }
        expect(assigns(:subscriptions)).to all(have_attributes(status: 'canceled'))
      end
    end

    context 'with plan_id filter' do
      let(:other_plan) { create(:pwb_plan) }
      let!(:subscription_with_other_plan) { create(:pwb_subscription, plan: other_plan) }

      it 'filters subscriptions by plan' do
        get :index, params: { plan_id: other_plan.id }
        expect(assigns(:subscriptions)).to all(have_attributes(plan_id: other_plan.id))
      end
    end

    context 'with search parameter' do
      let(:searchable_website) { create(:pwb_website, subdomain: 'searchable-site') }
      let!(:searchable_subscription) { create(:pwb_subscription, website: searchable_website, plan: plan) }

      it 'searches by website subdomain' do
        get :index, params: { search: 'searchable' }
        expect(assigns(:subscriptions)).to include(searchable_subscription)
      end
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { id: subscription.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the requested subscription' do
      get :show, params: { id: subscription.id }
      expect(assigns(:subscription)).to eq(subscription)
    end

    it 'assigns subscription events' do
      get :show, params: { id: subscription.id }
      expect(assigns(:events)).to be_present.or be_empty
    end
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new
      expect(response).to have_http_status(:success)
    end

    it 'assigns a new subscription' do
      get :new
      expect(assigns(:subscription)).to be_a_new(Pwb::Subscription)
    end

    it 'assigns available websites without subscriptions' do
      get :new
      expect(assigns(:websites)).to be_present.or be_empty
    end

    it 'assigns active plans' do
      create(:pwb_plan, :starter) # Ensure at least one active plan exists
      get :new
      expect(assigns(:plans)).to be_present
    end
  end

  describe 'POST #create' do
    let(:website_without_subscription) { create(:pwb_website, subdomain: 'new-site') }

    let(:valid_params) do
      {
        pwb_subscription: {
          website_id: website_without_subscription.id,
          plan_id: plan.id,
          status: 'trialing',
          trial_ends_at: 14.days.from_now,
          current_period_starts_at: Time.current,
          current_period_ends_at: 14.days.from_now
        }
      }
    end

    let(:invalid_params) do
      {
        pwb_subscription: {
          website_id: nil,
          plan_id: nil
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new subscription' do
        expect do
          post :create, params: valid_params
        end.to change(Pwb::Subscription, :count).by(1)
      end

      it 'redirects to the created subscription' do
        post :create, params: valid_params
        expect(response).to redirect_to(tenant_admin_subscription_path(Pwb::Subscription.last))
      end

      it 'sets a success notice' do
        post :create, params: valid_params
        expect(flash[:notice]).to include('created successfully')
      end

      context 'when plan has trial days' do
        let(:plan_with_trial) { create(:pwb_plan, trial_days: 14) }

        it 'starts a trial for the subscription' do
          post :create, params: {
            pwb_subscription: {
              website_id: website_without_subscription.id,
              plan_id: plan_with_trial.id
            }
          }
          subscription = Pwb::Subscription.last
          expect(subscription.status).to eq('trialing')
        end
      end

      context 'when plan has no trial days' do
        let(:plan_without_trial) { create(:pwb_plan, :no_trial) }

        it 'activates the subscription immediately' do
          post :create, params: {
            pwb_subscription: {
              website_id: website_without_subscription.id,
              plan_id: plan_without_trial.id
            }
          }
          subscription = Pwb::Subscription.last
          expect(subscription.status).to eq('active')
        end
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new subscription' do
        expect do
          post :create, params: invalid_params
        end.not_to change(Pwb::Subscription, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET #edit' do
    it 'returns a successful response' do
      get :edit, params: { id: subscription.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the requested subscription' do
      get :edit, params: { id: subscription.id }
      expect(assigns(:subscription)).to eq(subscription)
    end

    it 'assigns active plans' do
      get :edit, params: { id: subscription.id }
      expect(assigns(:plans)).to be_present
    end
  end

  describe 'PATCH #update' do
    let(:new_attributes) do
      {
        pwb_subscription: {
          external_id: 'sub_updated123',
          external_customer_id: 'cus_updated456'
        }
      }
    end

    context 'with valid parameters' do
      it 'updates the subscription' do
        patch :update, params: { id: subscription.id }.merge(new_attributes)
        subscription.reload
        expect(subscription.external_id).to eq('sub_updated123')
        expect(subscription.external_customer_id).to eq('cus_updated456')
      end

      it 'redirects to the subscription' do
        patch :update, params: { id: subscription.id }.merge(new_attributes)
        expect(response).to redirect_to(tenant_admin_subscription_path(subscription))
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the subscription' do
      subscription_to_delete = create(:pwb_subscription, plan: plan)
      expect do
        delete :destroy, params: { id: subscription_to_delete.id }
      end.to change(Pwb::Subscription, :count).by(-1)
    end

    it 'redirects to subscriptions index' do
      delete :destroy, params: { id: subscription.id }
      expect(response).to redirect_to(tenant_admin_subscriptions_path)
    end

    it 'sets a success notice' do
      delete :destroy, params: { id: subscription.id }
      expect(flash[:notice]).to include('deleted')
    end
  end

  describe 'POST #activate' do
    let(:trialing_subscription) { create(:pwb_subscription, :trialing, plan: plan) }

    it 'activates a trialing subscription' do
      post :activate, params: { id: trialing_subscription.id }
      trialing_subscription.reload
      expect(trialing_subscription.status).to eq('active')
    end

    it 'redirects to the subscription' do
      post :activate, params: { id: trialing_subscription.id }
      expect(response).to redirect_to(tenant_admin_subscription_path(trialing_subscription))
    end

    it 'sets a success notice' do
      post :activate, params: { id: trialing_subscription.id }
      expect(flash[:notice]).to include('activated')
    end

    context 'when subscription cannot be activated' do
      let(:expired_subscription) { create(:pwb_subscription, :expired, plan: plan) }

      it 'redirects with an alert' do
        post :activate, params: { id: expired_subscription.id }
        expect(flash[:alert]).to include('Cannot activate')
      end
    end
  end

  describe 'POST #cancel' do
    let(:active_subscription) { create(:pwb_subscription, :active, plan: plan) }

    it 'cancels an active subscription' do
      post :cancel, params: { id: active_subscription.id }
      active_subscription.reload
      expect(active_subscription.status).to eq('canceled')
    end

    it 'redirects to the subscription' do
      post :cancel, params: { id: active_subscription.id }
      expect(response).to redirect_to(tenant_admin_subscription_path(active_subscription))
    end

    it 'sets a success notice' do
      post :cancel, params: { id: active_subscription.id }
      expect(flash[:notice]).to include('canceled')
    end

    context 'when subscription cannot be canceled' do
      let(:expired_subscription) { create(:pwb_subscription, :expired, plan: plan) }

      it 'redirects with an alert' do
        post :cancel, params: { id: expired_subscription.id }
        expect(flash[:alert]).to include('Cannot cancel')
      end
    end
  end

  describe 'POST #change_plan' do
    let(:active_subscription) { create(:pwb_subscription, :active, plan: plan) }
    let(:new_plan) { create(:pwb_plan, :professional) }

    it 'changes the subscription plan' do
      post :change_plan, params: { id: active_subscription.id, new_plan_id: new_plan.id }
      active_subscription.reload
      expect(active_subscription.plan).to eq(new_plan)
    end

    it 'redirects to the subscription' do
      post :change_plan, params: { id: active_subscription.id, new_plan_id: new_plan.id }
      expect(response).to redirect_to(tenant_admin_subscription_path(active_subscription))
    end

    it 'sets a success notice' do
      post :change_plan, params: { id: active_subscription.id, new_plan_id: new_plan.id }
      expect(flash[:notice]).to include('Plan changed')
    end
  end

  describe 'POST #expire_trials' do
    let!(:expired_trial) { create(:pwb_subscription, :trial_expired, plan: plan) }
    let!(:active_trial) { create(:pwb_subscription, :trialing, plan: plan) }

    it 'expires trial subscriptions that have ended' do
      post :expire_trials
      expired_trial.reload
      expect(expired_trial.status).to eq('expired')
    end

    it 'does not affect active trials' do
      post :expire_trials
      active_trial.reload
      expect(active_trial.status).to eq('trialing')
    end

    it 'redirects to subscriptions index' do
      post :expire_trials
      expect(response).to redirect_to(tenant_admin_subscriptions_path)
    end

    it 'sets a notice with the count' do
      post :expire_trials
      expect(flash[:notice]).to include('Expired')
    end
  end

  describe 'authorization' do
    context 'when user is not a tenant admin' do
      let(:regular_user) { create(:pwb_user, email: 'user@example.com', website: website) }

      before do
        sign_in regular_user, scope: :user
      end

      it 'denies access to index' do
        get :index
        expect(response).to have_http_status(:forbidden)
      end

      it 'denies access to show' do
        get :show, params: { id: subscription.id }
        expect(response).to have_http_status(:forbidden)
      end

      it 'denies access to activate' do
        post :activate, params: { id: subscription.id }
        expect(response).to have_http_status(:forbidden)
      end

      it 'denies access to cancel' do
        post :cancel, params: { id: subscription.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
