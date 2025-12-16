# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::OnboardingController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-onboarding') }
  let(:user) { create(:pwb_user, email: 'owner@example.com', website: website) }
  let!(:membership) { create(:pwb_user_membership, user: user, website: website, role: 'owner', active: true) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    @request.host = "#{website.subdomain}.example.com"
    allow(Pwb::Current).to receive(:website).and_return(website)
    sign_in user, scope: :user
  end

  describe 'GET #show' do
    context 'step 1 (welcome)' do
      it 'renders the welcome view' do
        get :show, params: { step: 1 }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:welcome)
      end

      it 'assigns steps and current step info' do
        get :show, params: { step: 1 }
        expect(assigns(:steps)).to be_present
        expect(assigns(:step)).to eq(1)
        expect(assigns(:current_step_info)[:name]).to eq('welcome')
      end
    end

    context 'step 2 (profile)' do
      it 'renders the profile view' do
        get :show, params: { step: 2 }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:profile)
      end

      it 'assigns or builds agency' do
        get :show, params: { step: 2 }
        expect(assigns(:agency)).to be_present
      end
    end

    context 'step 3 (property)' do
      it 'renders the property view' do
        get :show, params: { step: 3 }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:property)
      end

      it 'assigns a new property' do
        get :show, params: { step: 3 }
        expect(assigns(:property)).to be_a_new(Pwb::RealtyAsset)
      end
    end

    context 'step 4 (theme)' do
      it 'renders the theme view' do
        get :show, params: { step: 4 }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:theme)
      end

      it 'assigns available themes' do
        get :show, params: { step: 4 }
        expect(assigns(:themes)).to be_an(Array)
        expect(assigns(:themes)).not_to be_empty
      end
    end

    context 'step 5 (complete)' do
      it 'renders the complete view' do
        get :show, params: { step: 5 }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:complete)
      end

      it 'marks onboarding as completed' do
        expect {
          get :show, params: { step: 5 }
        }.to change { user.reload.site_admin_onboarding_completed_at }.from(nil)
      end
    end

    context 'without step parameter' do
      it 'defaults to step 1' do
        get :show
        expect(assigns(:step)).to eq(1)
      end

      context 'when user has progressed to step 3' do
        before { user.update!(onboarding_step: 3) }

        it 'shows step 3' do
          get :show
          expect(assigns(:step)).to eq(3)
        end
      end
    end

    context 'when onboarding is already completed' do
      before { user.update!(site_admin_onboarding_completed_at: Time.current) }

      it 'redirects to dashboard when accessing without step param' do
        get :show
        expect(response).to redirect_to(site_admin_dashboard_path)
      end

      it 'allows explicit step access' do
        get :show, params: { step: 1 }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST #update' do
    context 'step 1 (welcome)' do
      it 'advances to step 2' do
        post :update, params: { step: 1 }
        expect(response).to redirect_to(site_admin_onboarding_path(step: 2))
        expect(user.reload.onboarding_step).to eq(2)
      end
    end

    context 'step 2 (profile)' do
      let(:valid_agency_params) do
        {
          agency: {
            display_name: 'Test Agency',
            email_primary: 'agency@example.com',
            phone_primary: '+1 555-1234'
          }
        }
      end

      it 'saves the agency and advances to step 3' do
        post :update, params: { step: 2 }.merge(valid_agency_params)
        expect(response).to redirect_to(site_admin_onboarding_path(step: 3))
        expect(website.reload.agency.display_name).to eq('Test Agency')
      end

      it 're-renders profile on validation error' do
        post :update, params: { step: 2, agency: { display_name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:profile)
      end
    end

    context 'step 4 (theme)' do
      it 'saves the theme and advances to step 5' do
        post :update, params: { step: 4, theme_name: 'flavor' }
        expect(response).to redirect_to(site_admin_onboarding_path(step: 5))
        expect(website.reload.theme_name).to eq('flavor')
      end

      it 're-renders theme on invalid theme selection' do
        post :update, params: { step: 4, theme_name: 'invalid-theme' }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:theme)
      end
    end
  end

  describe 'POST #skip_step' do
    context 'step 3 (property)' do
      it 'skips the property step and advances' do
        post :skip_step, params: { step: 3 }
        expect(response).to redirect_to(site_admin_onboarding_path(step: 4))
      end
    end

    context 'non-skippable step' do
      it 'does not allow skipping step 2' do
        post :skip_step, params: { step: 2 }
        expect(response).to redirect_to(site_admin_onboarding_path(step: 2))
        expect(flash[:alert]).to include('cannot be skipped')
      end
    end
  end

  describe 'POST #restart' do
    before do
      user.update!(
        onboarding_step: 5,
        site_admin_onboarding_completed_at: Time.current
      )
    end

    it 'resets onboarding progress' do
      post :restart
      user.reload
      expect(user.onboarding_step).to eq(1)
      expect(user.site_admin_onboarding_completed_at).to be_nil
    end

    it 'redirects to step 1' do
      post :restart
      expect(response).to redirect_to(site_admin_onboarding_path(step: 1))
    end
  end

  describe 'authentication' do
    context 'when user is not signed in' do
      before { sign_out user }

      it 'redirects to root path' do
        get :show, params: { step: 1 }
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user has no access to website' do
      let(:other_user) { create(:pwb_user, email: 'other@example.com') }

      before do
        sign_out user
        sign_in other_user, scope: :user
      end

      it 'redirects with access denied' do
        get :show, params: { step: 1 }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have access")
      end
    end
  end
end
