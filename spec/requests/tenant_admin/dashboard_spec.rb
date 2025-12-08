# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TenantAdmin::Dashboard', type: :request do
  let(:website) { create(:pwb_website, subdomain: 'tenant-admin-test') }
  let(:admin_user) { create(:pwb_user, email: 'tenant-admin@example.com', website: website) }
  let(:regular_user) { create(:pwb_user, email: 'regular@example.com', website: website) }

  describe 'GET /tenant_admin' do
    context 'when BYPASS_ADMIN_AUTH is enabled' do
      before do
        ENV['BYPASS_ADMIN_AUTH'] = 'true'
      end

      after do
        ENV['BYPASS_ADMIN_AUTH'] = nil
      end

      it 'allows access without authentication' do
        get '/tenant_admin'
        expect(response).to have_http_status(:ok)
      end

      it 'displays system overview statistics' do
        get '/tenant_admin'
        expect(response.body).to include('Dashboard').or include('tenant_admin')
      end
    end

    context 'when authentication is required' do
      before do
        ENV['BYPASS_ADMIN_AUTH'] = nil
        ENV['TENANT_ADMIN_EMAILS'] = 'tenant-admin@example.com'
      end

      after do
        ENV['TENANT_ADMIN_EMAILS'] = nil
      end

      it 'redirects unauthenticated users to sign in' do
        get '/tenant_admin'
        expect(response).to have_http_status(:redirect)
      end

      it 'denies access to non-tenant-admin users' do
        sign_in regular_user
        get '/tenant_admin'
        expect(response).to have_http_status(:forbidden)
      end

      it 'allows access to tenant admin users' do
        sign_in admin_user
        get '/tenant_admin'
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
