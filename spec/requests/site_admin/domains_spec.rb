# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::DomainsController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'domain-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@domain-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
    # Enable custom_domain feature for tests
    allow_any_instance_of(SiteAdmin::DomainsController).to receive(:require_feature).and_return(true)
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/domain (show)' do
    it 'renders the domain settings page' do
      get site_admin_domain_path, headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'with no custom domain set' do
      it 'displays setup instructions' do
        get site_admin_domain_path, headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'with custom domain set but not verified' do
      before do
        website.update!(
          custom_domain: 'example.com',
          custom_domain_verified: false,
          custom_domain_verification_token: 'test-token-123'
        )
      end

      it 'displays verification instructions' do
        get site_admin_domain_path, headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'with verified custom domain' do
      before do
        website.update!(
          custom_domain: 'example.com',
          custom_domain_verified: true,
          custom_domain_verified_at: Time.current
        )
      end

      it 'shows verified status' do
        get site_admin_domain_path, headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'PATCH /site_admin/domain (update)' do
    it 'sets a new custom domain' do
      patch site_admin_domain_path,
            params: { website: { custom_domain: 'mynewdomain.com' } },
            headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

      website.reload
      expect(website.custom_domain).to eq('mynewdomain.com')
      expect(website.custom_domain_verified).to be false
    end

    it 'redirects with notice' do
      patch site_admin_domain_path,
            params: { website: { custom_domain: 'new.example.com' } },
            headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

      expect(response).to redirect_to(site_admin_domain_path)
      expect(flash[:notice]).to be_present
    end

    context 'when removing domain' do
      before do
        website.update!(
          custom_domain: 'old.example.com',
          custom_domain_verified: true
        )
      end

      it 'clears the custom domain' do
        patch site_admin_domain_path,
              params: { website: { custom_domain: '' } },
              headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

        website.reload
        expect(website.custom_domain).to be_blank
      end

      it 'redirects with removal notice' do
        patch site_admin_domain_path,
              params: { website: { custom_domain: '' } },
              headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

        expect(response).to redirect_to(site_admin_domain_path)
        expect(flash[:notice]).to include('removed')
      end
    end

    context 'when changing domain' do
      before do
        website.update!(
          custom_domain: 'old.example.com',
          custom_domain_verified: true,
          custom_domain_verified_at: 1.day.ago
        )
      end

      it 'resets verification status' do
        patch site_admin_domain_path,
              params: { website: { custom_domain: 'new.example.com' } },
              headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

        website.reload
        expect(website.custom_domain).to eq('new.example.com')
        expect(website.custom_domain_verified).to be false
        expect(website.custom_domain_verified_at).to be_nil
      end
    end
  end

  describe 'POST /site_admin/domain/verify' do
    context 'without custom domain' do
      it 'redirects with error' do
        post verify_site_admin_domain_path,
             headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

        expect(response).to redirect_to(site_admin_domain_path)
        expect(flash[:alert]).to include('No custom domain')
      end
    end

    context 'with custom domain' do
      before do
        website.update!(
          custom_domain: 'verify.example.com',
          custom_domain_verification_token: 'test-token'
        )
      end

      context 'when verification succeeds' do
        before do
          allow_any_instance_of(Pwb::Website).to receive(:verify_custom_domain!).and_return(true)
        end

        it 'redirects with success notice' do
          post verify_site_admin_domain_path,
               headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

          expect(response).to redirect_to(site_admin_domain_path)
          expect(flash[:notice]).to include('verified successfully')
        end
      end

      context 'when verification fails' do
        before do
          allow_any_instance_of(Pwb::Website).to receive(:verify_custom_domain!).and_return(false)
        end

        it 'redirects with error' do
          post verify_site_admin_domain_path,
               headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

          expect(response).to redirect_to(site_admin_domain_path)
          expect(flash[:alert]).to include('verification failed')
        end
      end
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users on show' do
      get site_admin_domain_path,
          headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on update' do
      patch site_admin_domain_path,
            params: { website: { custom_domain: 'hack.com' } },
            headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on verify' do
      post verify_site_admin_domain_path,
           headers: { 'HTTP_HOST' => 'domain-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
