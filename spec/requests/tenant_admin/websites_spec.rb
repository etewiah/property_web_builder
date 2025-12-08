# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TenantAdmin::Websites', type: :request do
  let(:website) { create(:pwb_website, subdomain: 'admin-site') }
  let(:admin_user) { create(:pwb_user, email: 'tenant-admin@example.com', website: website) }

  before do
    ENV['BYPASS_ADMIN_AUTH'] = 'true'
  end

  after do
    ENV['BYPASS_ADMIN_AUTH'] = nil
  end

  describe 'GET /tenant_admin/websites' do
    let!(:website_a) { create(:pwb_website, subdomain: 'site-alpha', company_display_name: 'Alpha Agency') }
    let!(:website_b) { create(:pwb_website, subdomain: 'site-beta', company_display_name: 'Beta Agency') }

    it 'returns a list of all websites' do
      get '/tenant_admin/websites'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('site-alpha').or include('Alpha')
      expect(response.body).to include('site-beta').or include('Beta')
    end

    it 'supports search by subdomain' do
      get '/tenant_admin/websites', params: { search: 'alpha' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('site-alpha').or include('Alpha')
    end

    it 'supports search by company name' do
      get '/tenant_admin/websites', params: { search: 'Beta Agency' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Beta')
    end
  end

  describe 'GET /tenant_admin/websites/:id' do
    let!(:target_website) { create(:pwb_website, subdomain: 'target-site') }

    it 'shows website details' do
      get "/tenant_admin/websites/#{target_website.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('target-site')
    end

    it 'shows related statistics' do
      get "/tenant_admin/websites/#{target_website.id}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /tenant_admin/websites/new' do
    it 'renders the new website form' do
      get '/tenant_admin/websites/new'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /tenant_admin/websites' do
    let(:valid_params) do
      {
        website: {
          subdomain: 'new-tenant-site',
          company_display_name: 'New Company',
          theme_name: 'starter',
          default_currency: 'USD',
          default_area_unit: 'sq_ft',
          default_client_locale: 'en'
        }
      }
    end

    it 'creates a new website with valid params' do
      expect {
        post '/tenant_admin/websites', params: valid_params
      }.to change(Pwb::Website, :count).by(1)

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include('new-tenant-site').or include('successfully')
    end

    it 'returns error for invalid params' do
      post '/tenant_admin/websites', params: { website: { subdomain: '' } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    context 'with seed_data option' do
      it 'seeds website content when requested' do
        post '/tenant_admin/websites', params: valid_params.deep_merge(website: { seed_data: '1' })
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /tenant_admin/websites/:id/edit' do
    let!(:target_website) { create(:pwb_website, subdomain: 'edit-site') }

    it 'renders the edit form' do
      get "/tenant_admin/websites/#{target_website.id}/edit"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('edit-site')
    end
  end

  describe 'PATCH /tenant_admin/websites/:id' do
    let!(:target_website) { create(:pwb_website, subdomain: 'update-site') }

    it 'updates website attributes' do
      patch "/tenant_admin/websites/#{target_website.id}", params: {
        website: { company_display_name: 'Updated Company Name' }
      }
      expect(response).to have_http_status(:redirect)

      target_website.reload
      expect(target_website.company_display_name).to eq('Updated Company Name')
    end

    it 'returns error for invalid updates' do
      patch "/tenant_admin/websites/#{target_website.id}", params: {
        website: { subdomain: '' }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /tenant_admin/websites/:id' do
    let!(:target_website) { create(:pwb_website, subdomain: 'delete-site') }

    it 'deletes the website' do
      expect {
        delete "/tenant_admin/websites/#{target_website.id}"
      }.to change(Pwb::Website, :count).by(-1)

      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'POST /tenant_admin/websites/:id/seed' do
    let!(:target_website) { create(:pwb_website, subdomain: 'seed-site') }

    it 'seeds website content' do
      post "/tenant_admin/websites/#{target_website.id}/seed"
      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include('seeded').or include('success')
    end
  end
end
