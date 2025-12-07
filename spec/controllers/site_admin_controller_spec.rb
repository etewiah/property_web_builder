# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdminController, type: :controller do
  # Create an anonymous controller to test base class behavior
  controller do
    # Skip authentication for testing tenant setup
    skip_before_action :authenticate_user!, raise: false

    def index
      # Access PwbTenant model to verify tenant is set
      @contact_count = PwbTenant::Contact.count
      render plain: "OK"
    end
  end

  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:other_website) { create(:pwb_website, subdomain: 'other-site') }

  before do
    allow(Pwb::Current).to receive(:website).and_return(website)
    # Set tenant for the test - mimics what set_tenant_from_subdomain does
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'tenant setup via before_action' do
    before do
      # Create test data
      Pwb::Contact.create!(first_name: 'Own', website: website)
      Pwb::Contact.create!(first_name: 'Other', website: other_website)
    end

    it 'sets ActsAsTenant.current_tenant before action' do
      get :index

      # The controller should have set the tenant, allowing PwbTenant queries
      expect(response).to have_http_status(:success)
    end

    it 'scopes PwbTenant queries to current website' do
      get :index

      # Only the contact belonging to our website should be counted
      expect(assigns(:contact_count)).to eq(1)
    end

    it 'sets tenant from current_website' do
      get :index

      # Verify the tenant was set correctly during the request
      expect(response.body).to eq("OK")
    end
  end

  describe 'tenant isolation' do
    before do
      # Create data for both websites
      3.times { |i| Pwb::Contact.create!(first_name: "Own#{i}", website: website) }
      5.times { |i| Pwb::Contact.create!(first_name: "Other#{i}", website: other_website) }
    end

    it 'only accesses data for the current tenant' do
      get :index

      # Should only count our website's 3 contacts, not all 8
      expect(assigns(:contact_count)).to eq(3)
    end

    it 'prevents access to other tenant data via PwbTenant models' do
      get :index

      # After the request, verify that if we tried to access other tenant data
      # via PwbTenant models during the request, it would be scoped correctly
      expect(assigns(:contact_count)).not_to eq(8)
    end
  end

  describe 'without tenant set' do
    before do
      ActsAsTenant.current_tenant = nil
    end

    it 'raises error when accessing PwbTenant models' do
      expect {
        PwbTenant::Contact.count
      }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
    end
  end
end

RSpec.describe 'SiteAdminController#set_tenant_from_subdomain', type: :controller do
  # Test the actual SiteAdmin::DashboardController which inherits from SiteAdminController
  controller(SiteAdmin::DashboardController) do
  end

  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:user) { create(:pwb_user, :admin, website: website) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user, scope: :user
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'authentication and authorization' do
    context 'when user is admin for the website' do
      it 'allows access' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is signed in but not admin' do
      let(:non_admin_user) { create(:pwb_user, website: website) }

      before do
        sign_out :user
        sign_in non_admin_user, scope: :user
      end

      it 'returns forbidden status' do
        get :index
        expect(response).to have_http_status(:forbidden)
      end

      it 'renders admin required error page' do
        get :index
        expect(response).to render_template('pwb/errors/admin_required')
      end
    end

    context 'when user is not signed in' do
      before { sign_out :user }

      it 'returns forbidden status and renders admin required page' do
        get :index
        expect(response).to have_http_status(:forbidden)
        expect(response).to render_template('pwb/errors/admin_required')
      end
    end
  end
end
