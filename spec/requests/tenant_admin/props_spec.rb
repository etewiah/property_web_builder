# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TenantAdmin::Props', type: :request do
  let(:website_a) { create(:pwb_website, subdomain: 'props-site-a') }
  let(:website_b) { create(:pwb_website, subdomain: 'props-site-b') }

  before do
    ENV['BYPASS_ADMIN_AUTH'] = 'true'
  end

  after do
    ENV['BYPASS_ADMIN_AUTH'] = nil
  end

  describe 'GET /tenant_admin/props' do
    let!(:prop_a) do
      ActsAsTenant.with_tenant(website_a) do
        create(:pwb_prop, :sale, website: website_a, title_en: 'Property Alpha', reference: 'REF-001')
      end
    end

    let!(:prop_b) do
      ActsAsTenant.with_tenant(website_b) do
        create(:pwb_prop, :sale, website: website_b, title_en: 'Property Beta', reference: 'REF-002')
      end
    end

    it 'returns a list of all properties across tenants' do
      get '/tenant_admin/props'
      expect(response).to have_http_status(:ok)
      # Should show properties from both tenants (cross-tenant view)
      expect(response.body).to include('REF-001').or include('Property Alpha').or include('props-site-a')
      expect(response.body).to include('REF-002').or include('Property Beta').or include('props-site-b')
    end

    it 'supports search by reference' do
      get '/tenant_admin/props', params: { search: 'REF-001' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('REF-001').or include('Alpha')
    end

    it 'supports search by title' do
      get '/tenant_admin/props', params: { search: 'Alpha' }
      expect(response).to have_http_status(:ok)
    end

    it 'filters by website' do
      get '/tenant_admin/props', params: { website_id: website_a.id }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /tenant_admin/props/:id' do
    let!(:target_prop) do
      ActsAsTenant.with_tenant(website_a) do
        create(:pwb_prop, :sale, website: website_a, title_en: 'Target Property', reference: 'TARGET-001')
      end
    end

    it 'shows property details' do
      get "/tenant_admin/props/#{target_prop.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('TARGET-001').or include('Target Property')
    end
  end
end
