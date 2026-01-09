# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantAdmin::PlansController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:admin_user) { create(:pwb_user, email: 'admin@example.com', website: website) }
  let(:plan) { create(:pwb_plan) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
    sign_in admin_user, scope: :user
  end

  describe 'GET #index' do
    let!(:plans) { create_list(:pwb_plan, 3) }
    let!(:inactive_plan) { create(:pwb_plan, :inactive) }

    it 'returns a successful response' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns @plans' do
      get :index
      expect(assigns(:plans)).to be_present
    end

    it 'assigns @stats with plan statistics' do
      get :index
      expect(assigns(:stats)).to include(:total, :active, :public, :subscriptions)
    end

    context 'with active filter' do
      it 'filters plans by active status' do
        get :index, params: { active: 'true' }
        expect(assigns(:plans)).to all(have_attributes(active: true))
      end

      it 'filters plans by inactive status' do
        get :index, params: { active: 'false' }
        expect(assigns(:plans)).to all(have_attributes(active: false))
      end
    end

    context 'with search parameter' do
      let!(:searchable_plan) { create(:pwb_plan, name: 'premium_plan', display_name: 'Premium Plan') }

      it 'searches by name' do
        get :index, params: { search: 'premium' }
        expect(assigns(:plans)).to include(searchable_plan)
      end

      it 'searches by display_name' do
        get :index, params: { search: 'Premium' }
        expect(assigns(:plans)).to include(searchable_plan)
      end
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { id: plan.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the requested plan' do
      get :show, params: { id: plan.id }
      expect(assigns(:plan)).to eq(plan)
    end

    it 'assigns recent subscriptions for the plan' do
      subscription = create(:pwb_subscription, plan: plan)
      get :show, params: { id: plan.id }
      expect(assigns(:subscriptions)).to include(subscription)
    end
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new
      expect(response).to have_http_status(:success)
    end

    it 'assigns a new plan with defaults' do
      get :new
      expect(assigns(:plan)).to be_a_new(Pwb::Plan)
      expect(assigns(:plan).active).to be true
      expect(assigns(:plan).public).to be true
      expect(assigns(:plan).billing_interval).to eq('month')
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        pwb_plan: {
          name: 'new_plan',
          slug: 'new-plan',
          display_name: 'New Plan',
          description: 'A new plan',
          price_cents: 4900,
          price_currency: 'USD',
          billing_interval: 'month',
          trial_days: 14,
          property_limit: 50,
          user_limit: 5,
          active: true,
          public: true,
          position: 1,
          features: ['basic_themes']
        }
      }
    end

    let(:invalid_params) do
      {
        pwb_plan: {
          name: '',
          slug: '',
          display_name: ''
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new plan' do
        expect do
          post :create, params: valid_params
        end.to change(Pwb::Plan, :count).by(1)
      end

      it 'redirects to the created plan' do
        post :create, params: valid_params
        expect(response).to redirect_to(tenant_admin_plan_path(Pwb::Plan.last))
      end

      it 'sets a success notice' do
        post :create, params: valid_params
        expect(flash[:notice]).to include('created successfully')
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new plan' do
        expect do
          post :create, params: invalid_params
        end.not_to change(Pwb::Plan, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET #edit' do
    it 'returns a successful response' do
      get :edit, params: { id: plan.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the requested plan' do
      get :edit, params: { id: plan.id }
      expect(assigns(:plan)).to eq(plan)
    end
  end

  describe 'PATCH #update' do
    let(:new_attributes) do
      {
        pwb_plan: {
          display_name: 'Updated Plan Name',
          price_cents: 5900
        }
      }
    end

    context 'with valid parameters' do
      it 'updates the plan' do
        patch :update, params: { id: plan.id }.merge(new_attributes)
        plan.reload
        expect(plan.display_name).to eq('Updated Plan Name')
        expect(plan.price_cents).to eq(5900)
      end

      it 'redirects to the plan' do
        patch :update, params: { id: plan.id }.merge(new_attributes)
        expect(response).to redirect_to(tenant_admin_plan_path(plan))
      end
    end

    context 'with invalid parameters' do
      it 'does not update the plan' do
        original_name = plan.display_name
        patch :update, params: { id: plan.id, pwb_plan: { display_name: '' } }
        plan.reload
        expect(plan.display_name).to eq(original_name)
      end

      it 'renders the edit template' do
        patch :update, params: { id: plan.id, pwb_plan: { display_name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when plan has no subscriptions' do
      it 'destroys the plan' do
        plan_to_delete = create(:pwb_plan)
        expect do
          delete :destroy, params: { id: plan_to_delete.id }
        end.to change(Pwb::Plan, :count).by(-1)
      end

      it 'redirects to plans index' do
        delete :destroy, params: { id: plan.id }
        expect(response).to redirect_to(tenant_admin_plans_path)
      end
    end

    context 'when plan has subscriptions' do
      let!(:subscription) { create(:pwb_subscription, plan: plan) }

      it 'does not destroy the plan' do
        expect do
          delete :destroy, params: { id: plan.id }
        end.not_to change(Pwb::Plan, :count)
      end

      it 'redirects with an alert' do
        delete :destroy, params: { id: plan.id }
        expect(response).to redirect_to(tenant_admin_plans_path)
        expect(flash[:alert]).to include('Cannot delete')
      end
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
        get :show, params: { id: plan.id }
        expect(response).to have_http_status(:forbidden)
      end

      it 'denies access to create' do
        post :create, params: { pwb_plan: { name: 'test' } }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
