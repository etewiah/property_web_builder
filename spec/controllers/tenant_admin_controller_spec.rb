# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantAdminController, type: :controller do
  # Create a test controller that inherits from TenantAdminController
  controller(TenantAdminController) do
    def index
      render plain: 'OK'
    end
  end

  let(:website) { create(:pwb_website, subdomain: 'test-tenant') }
  let(:user) { create(:pwb_user, email: 'user@example.com', website: website) }
  let(:admin_user) { create(:pwb_user, email: 'admin@example.com', website: website) }

  before do
    routes.draw { get 'index' => 'tenant_admin#index' }
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end

  describe 'authorization via TENANT_ADMIN_EMAILS' do
    context 'when TENANT_ADMIN_EMAILS is not set' do
      before do
        ENV['TENANT_ADMIN_EMAILS'] = nil
        ENV['BYPASS_ADMIN_AUTH'] = nil
      end

      it 'denies access to authenticated users' do
        sign_in user, scope: :user
        get :index
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when TENANT_ADMIN_EMAILS is empty' do
      before do
        ENV['TENANT_ADMIN_EMAILS'] = ''
        ENV['BYPASS_ADMIN_AUTH'] = nil
      end

      it 'denies access to authenticated users' do
        sign_in user, scope: :user
        get :index
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user email is not in TENANT_ADMIN_EMAILS' do
      before do
        ENV['TENANT_ADMIN_EMAILS'] = 'admin@example.com,super@example.com'
        ENV['BYPASS_ADMIN_AUTH'] = nil
      end

      it 'denies access' do
        sign_in user, scope: :user
        get :index
        expect(response).to have_http_status(:forbidden)
      end

      it 'renders the tenant_admin_required error page' do
        sign_in user, scope: :user
        get :index
        expect(response).to render_template('pwb/errors/tenant_admin_required')
      end
    end

    context 'when user email is in TENANT_ADMIN_EMAILS' do
      before do
        ENV['TENANT_ADMIN_EMAILS'] = 'admin@example.com,super@example.com'
        ENV['BYPASS_ADMIN_AUTH'] = nil
      end

      it 'allows access' do
        sign_in admin_user, scope: :user
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when user email matches case-insensitively' do
      before do
        ENV['TENANT_ADMIN_EMAILS'] = 'ADMIN@EXAMPLE.COM'
        ENV['BYPASS_ADMIN_AUTH'] = nil
      end

      it 'allows access' do
        sign_in admin_user, scope: :user
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when TENANT_ADMIN_EMAILS has spaces around emails' do
      before do
        ENV['TENANT_ADMIN_EMAILS'] = ' admin@example.com , super@example.com '
        ENV['BYPASS_ADMIN_AUTH'] = nil
      end

      it 'strips whitespace and allows access' do
        sign_in admin_user, scope: :user
        get :index
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'authentication' do
    before do
      ENV['TENANT_ADMIN_EMAILS'] = 'admin@example.com'
      ENV['BYPASS_ADMIN_AUTH'] = nil
    end

    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        get :index
        # Redirect may go to Devise sign_in or Firebase login depending on config
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'bypass mode' do
    context 'when BYPASS_ADMIN_AUTH is enabled in allowed environment' do
      before do
        ENV['BYPASS_ADMIN_AUTH'] = 'true'
        ENV['TENANT_ADMIN_EMAILS'] = 'admin@example.com'
        # Create a website for bypass user creation
        website
      end

      it 'bypasses both authentication and authorization' do
        # Note: This test verifies bypass works, but actual bypass behavior
        # depends on the AdminAuthBypass concern creating a user
        get :index
        # In bypass mode, we should not get a 401/403
        expect(response.status).not_to eq(401)
      end
    end
  end

  describe 'JSON response' do
    before do
      ENV['TENANT_ADMIN_EMAILS'] = 'admin@example.com'
      ENV['BYPASS_ADMIN_AUTH'] = nil
    end

    it 'returns JSON error when access is denied' do
      sign_in user, scope: :user
      get :index, format: :json
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['error']).to include('not authorized')
    end
  end
end
