# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TenantAdmin Authorization', type: :controller do
  controller(TenantAdminController) do
    def index
      render plain: 'OK'
    end
  end

  let(:website) { create(:pwb_website, subdomain: 'test-site') }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    routes.draw { get 'index' => 'tenant_admin#index' }
  end

  describe 'authentication requirement' do
    context 'when user is not signed in' do
      it 'redirects to login page' do
        get :index
        expect(response).to be_redirect
        expect(response.location).to include('firebase_login').or include('sign_in')
      end
    end
  end

  describe 'email whitelist authorization' do
    context 'when user email is in TENANT_ADMIN_EMAILS' do
      let(:user) { create(:pwb_user, email: 'admin@example.com', website: website) }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com,super@example.com')
        sign_in user, scope: :user
      end

      it 'allows access' do
        get :index
        expect(response).to have_http_status(:success)
        expect(response.body).to eq('OK')
      end
    end

    context 'when user email is in TENANT_ADMIN_EMAILS (case insensitive)' do
      let(:user) { create(:pwb_user, email: 'ADMIN@EXAMPLE.COM', website: website) }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
        sign_in user, scope: :user
      end

      it 'allows access regardless of case' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user email is NOT in TENANT_ADMIN_EMAILS' do
      let(:user) { create(:pwb_user, email: 'regular@example.com', website: website) }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
        sign_in user, scope: :user
      end

      it 'denies access with forbidden status' do
        get :index
        expect(response).to have_http_status(:forbidden)
      end

      it 'renders the tenant_admin_required error page' do
        get :index
        expect(response).to render_template('pwb/errors/tenant_admin_required')
      end
    end

    context 'when TENANT_ADMIN_EMAILS is empty' do
      let(:user) { create(:pwb_user, email: 'admin@example.com', website: website) }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('')
        sign_in user, scope: :user
      end

      it 'denies access to all users' do
        get :index
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when TENANT_ADMIN_EMAILS is not set' do
      let(:user) { create(:pwb_user, email: 'admin@example.com', website: website) }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('')
        sign_in user, scope: :user
      end

      it 'denies access to all users' do
        get :index
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when email list has whitespace' do
      let(:user) { create(:pwb_user, email: 'admin@example.com', website: website) }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('  admin@example.com  ,  super@example.com  ')
        sign_in user, scope: :user
      end

      it 'strips whitespace and allows access' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'JSON response' do
    let(:user) { create(:pwb_user, email: 'regular@example.com', website: website) }

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
      sign_in user, scope: :user
    end

    it 'returns JSON error for unauthorized JSON requests' do
      get :index, format: :json
      expect(response).to have_http_status(:forbidden)
      expect(response.content_type).to include('application/json')
      json = JSON.parse(response.body)
      expect(json['error']).to include('Access denied')
    end
  end

  describe 'bypass mechanism' do
    let(:user) { create(:pwb_user, email: 'regular@example.com', website: website) }

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
      sign_in user, scope: :user
    end

    context 'when BYPASS_ADMIN_AUTH is set' do
      before do
        allow(controller).to receive(:bypass_admin_auth?).and_return(true)
      end

      it 'allows access even for non-whitelisted users' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end
  end
end
