# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Public Multi-tenancy', type: :request do
  let!(:website1) { FactoryBot.create(:pwb_website, subdomain: 'tenant1', slug: 'tenant-1') }
  let!(:website2) { FactoryBot.create(:pwb_website, subdomain: 'tenant2', slug: 'tenant-2') }

  let!(:link1) do
    ActsAsTenant.with_tenant(website1) do
      FactoryBot.create(:pwb_link, website: website1, placement: 'top_nav', visible: true, slug: 'link1')
    end
  end
  let!(:link2) do
    ActsAsTenant.with_tenant(website2) do
      FactoryBot.create(:pwb_link, website: website2, placement: 'top_nav', visible: true, slug: 'link2')
    end
  end

  describe 'GET /api_public/v1/links' do
    it 'returns links for correct tenant via subdomain' do
      host! 'tenant1.example.com'
      get '/api_public/v1/links'
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      slugs = json.map { |l| l['slug'] }
      expect(slugs).to include('link1')
      expect(slugs).not_to include('link2')
    end

    it 'returns links for correct tenant via header' do
      get '/api_public/v1/links', headers: { 'X-Website-Slug' => 'tenant-2' }
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      slugs = json.map { |l| l['slug'] }
      expect(slugs).to include('link2')
      expect(slugs).not_to include('link1')
    end

    it 'header takes precedence over subdomain' do
      host! 'tenant1.example.com'
      get '/api_public/v1/links', headers: { 'X-Website-Slug' => 'tenant-2' }
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      slugs = json.map { |l| l['slug'] }
      expect(slugs).to include('link2')
      expect(slugs).not_to include('link1')
    end

    it 'isolates data between tenants', skip: 'host! not properly resetting between requests in same test' do
      # Tenant 1 request
      host! 'tenant1.example.com'
      Pwb::Current.reset
      get '/api_public/v1/links'
      tenant1_response = JSON.parse(response.body)

      # Tenant 2 request - reset current between requests
      host! 'tenant2.example.com'
      Pwb::Current.reset
      ActsAsTenant.current_tenant = nil
      get '/api_public/v1/links'
      tenant2_response = JSON.parse(response.body)

      # Should return different links
      tenant1_slugs = tenant1_response.map { |l| l['slug'] }
      tenant2_slugs = tenant2_response.map { |l| l['slug'] }

      expect(tenant1_slugs).to include('link1')
      expect(tenant1_slugs).not_to include('link2')
      expect(tenant2_slugs).to include('link2')
      expect(tenant2_slugs).not_to include('link1')
    end
  end
end
