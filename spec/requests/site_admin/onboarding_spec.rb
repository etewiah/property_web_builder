# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::OnboardingController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'onboard-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) do
    create(:pwb_user, :admin, website: website, email: 'admin@onboard-test.test',
           onboarding_step: 1, site_admin_onboarding_completed_at: nil)
  end

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/onboarding (show)' do
    it 'renders the onboarding welcome page' do
      get site_admin_onboarding_path, headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'step 1: welcome' do
      it 'renders the welcome step' do
        get site_admin_onboarding_path(step: 1), headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'step 2: profile' do
      before { admin_user.update!(onboarding_step: 2) }

      it 'renders the profile step' do
        get site_admin_onboarding_path(step: 2), headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'step 3: property' do
      before { admin_user.update!(onboarding_step: 3) }

      it 'renders the property step' do
        get site_admin_onboarding_path(step: 3), headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'step 4: theme' do
      before { admin_user.update!(onboarding_step: 4) }

      it 'renders the theme step' do
        get site_admin_onboarding_path(step: 4), headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'step 5: complete' do
      before { admin_user.update!(onboarding_step: 5) }

      it 'renders the complete step' do
        get site_admin_onboarding_complete_path, headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'when onboarding is completed' do
      before do
        admin_user.update!(
          onboarding_step: 5,
          site_admin_onboarding_completed_at: Time.current
        )
      end

      it 'redirects to dashboard when no step specified' do
        get site_admin_onboarding_path, headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        expect(response).to redirect_to(site_admin_root_path)
      end

      it 'allows visiting specific step' do
        get site_admin_onboarding_path(step: 2), headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /site_admin/onboarding/:step (update)' do
    context 'step 1: advance from welcome' do
      it 'advances to next step' do
        post site_admin_onboarding_path(step: 1),
             headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        admin_user.reload
        expect(admin_user.onboarding_step).to eq(2)
      end

      it 'redirects to next step' do
        post site_admin_onboarding_path(step: 1),
             headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        expect(response).to redirect_to(site_admin_onboarding_path(step: 2))
      end
    end

    context 'step 2: save profile' do
      before { admin_user.update!(onboarding_step: 2) }

      it 'saves agency details and advances' do
        post site_admin_onboarding_path(step: 2),
             params: {
               pwb_agency: {
                 display_name: 'My Agency',
                 email_primary: 'agency@test.com',
                 phone_number_primary: '+1234567890'
               }
             },
             headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        agency.reload
        expect(agency.display_name).to eq('My Agency')
        expect(admin_user.reload.onboarding_step).to eq(3)
      end

      it 'saves currency to website' do
        post site_admin_onboarding_path(step: 2),
             params: {
               pwb_agency: { display_name: 'Agency' },
               default_currency: 'EUR'
             },
             headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        website.reload
        expect(website.default_currency).to eq('EUR')
      end
    end

    context 'step 4: save theme' do
      before { admin_user.update!(onboarding_step: 4) }

      it 'saves theme selection' do
        available_theme = website.accessible_theme_names.first || 'starter'

        post site_admin_onboarding_path(step: 4),
             params: { theme_name: available_theme },
             headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        website.reload
        expect(website.theme_name).to eq(available_theme)
      end
    end
  end

  describe 'POST /site_admin/onboarding/:step/skip (skip_step)' do
    context 'step 3: property (skippable)' do
      before { admin_user.update!(onboarding_step: 3) }

      it 'skips to next step' do
        post site_admin_onboarding_skip_path(step: 3),
             headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        admin_user.reload
        expect(admin_user.onboarding_step).to eq(4)
      end
    end

    context 'step 2: profile (not skippable)' do
      before { admin_user.update!(onboarding_step: 2) }

      it 'does not allow skipping' do
        post site_admin_onboarding_skip_path(step: 2),
             headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

        expect(response).to redirect_to(site_admin_onboarding_path(step: 2))
        expect(flash[:alert]).to include('cannot be skipped')
      end
    end
  end

  describe 'GET /site_admin/onboarding/complete' do
    it 'renders the complete page' do
      get site_admin_onboarding_complete_path,
          headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /site_admin/onboarding/restart' do
    it 'redirects to onboarding' do
      post site_admin_onboarding_restart_path,
           headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users' do
      get site_admin_onboarding_path,
          headers: { 'HTTP_HOST' => 'onboard-test.test.localhost' }

      expect(response).to have_http_status(:redirect)
    end
  end
end
