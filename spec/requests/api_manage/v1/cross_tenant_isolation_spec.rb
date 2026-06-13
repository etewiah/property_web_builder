# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiManage::V1 Cross-Tenant Isolation', type: :request do
  let!(:website_a) { create(:pwb_website, subdomain: 'tenant-a') }
  let!(:website_b) { create(:pwb_website, subdomain: 'tenant-b') }
  let!(:user_a) { create(:pwb_user, :admin, website: website_a, email: 'admin@tenant-a.test') }
  let!(:user_b) { create(:pwb_user, :admin, website: website_b, email: 'admin@tenant-b.test') }

  describe 'Website Context Requirement' do
    context 'without website context' do
      it 'returns 400 when no tenant context can be resolved' do
        # Request without subdomain or X-Website-Slug header
        get '/api_manage/v1/en/pages',
            headers: { 'HTTP_HOST' => 'localhost' }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with X-Website-Slug header' do
      it 'accepts request with valid website subdomain' do
        get '/api_manage/v1/en/pages',
            headers: {
              'HTTP_HOST' => 'localhost',
              'X-Website-Slug' => website_a.subdomain,
              'X-User-Email' => user_a.email
            }

        expect(response).to have_http_status(:ok)
      end

      it 'returns 400 when X-Website-Slug does not match any website' do
        get '/api_manage/v1/en/pages',
            headers: {
              'HTTP_HOST' => 'localhost',
              'X-Website-Slug' => 'nonexistent-slug'
            }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with subdomain' do
      it 'accepts request with valid subdomain' do
        get '/api_manage/v1/en/pages',
            headers: { 'HTTP_HOST' => 'tenant-a.example.com', 'X-User-Email' => user_a.email }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'Pages Isolation' do
    let!(:page_a) do
      Pwb::Page.create!(
        slug: 'about-us',
        visible: true,
        website_id: website_a.id
      )
    end

    let!(:page_b) do
      Pwb::Page.create!(
        slug: 'contact',
        visible: true,
        website_id: website_b.id
      )
    end

    before do
      allow(Pwb::Current).to receive(:website).and_return(website_a)
    end

    describe 'GET /api_manage/v1/:locale/pages' do
      it 'only returns pages for current tenant' do
        get '/api_manage/v1/en/pages',
            headers: { 'HTTP_HOST' => 'tenant-a.example.com', 'X-User-Email' => user_a.email }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        page_ids = json['pages'].map { |p| p['id'] }
        expect(page_ids).to include(page_a.id)
        expect(page_ids).not_to include(page_b.id)
      end
    end

    describe 'GET /api_manage/v1/:locale/pages/:id' do
      it 'allows access to own page' do
        get "/api_manage/v1/en/pages/#{page_a.id}",
            headers: { 'HTTP_HOST' => 'tenant-a.example.com', 'X-User-Email' => user_a.email }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['page']['id']).to eq(page_a.id)
      end

      it 'denies access to another tenant page' do
        get "/api_manage/v1/en/pages/#{page_b.id}",
            headers: { 'HTTP_HOST' => 'tenant-a.example.com', 'X-User-Email' => user_a.email }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PageParts Isolation' do
    let!(:page_part_a) do
      Pwb::PagePart.create!(
        page_part_key: 'hero_section',
        page_slug: 'home',
        website_id: website_a.id
      )
    end

    let!(:page_part_b) do
      Pwb::PagePart.create!(
        page_part_key: 'hero_section',
        page_slug: 'home',
        website_id: website_b.id
      )
    end

    before do
      allow(Pwb::Current).to receive(:website).and_return(website_a)
    end

    describe 'GET /api_manage/v1/:locale/page_parts' do
      it 'only returns page_parts for current tenant' do
        get '/api_manage/v1/en/page_parts',
            headers: { 'HTTP_HOST' => 'tenant-a.example.com', 'X-User-Email' => user_a.email }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        part_ids = json['page_parts'].map { |p| p['id'] }
        expect(part_ids).to include(page_part_a.id)
        expect(part_ids).not_to include(page_part_b.id)
      end
    end

    describe 'GET /api_manage/v1/:locale/page_parts/:id' do
      it 'allows access to own page_part' do
        get "/api_manage/v1/en/page_parts/#{page_part_a.id}",
            headers: { 'HTTP_HOST' => 'tenant-a.example.com', 'X-User-Email' => user_a.email }

        expect(response).to have_http_status(:ok)
      end

      it 'denies access to another tenant page_part' do
        get "/api_manage/v1/en/page_parts/#{page_part_b.id}",
            headers: { 'HTTP_HOST' => 'tenant-a.example.com', 'X-User-Email' => user_a.email }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'AI Descriptions Isolation' do
    let!(:property_a) do
      Pwb::RealtyAsset.create!(
        reference: 'PROP-A-001',
        website: website_a,
        street_address: '123 Tenant A St'
      )
    end

    let!(:property_b) do
      Pwb::RealtyAsset.create!(
        reference: 'PROP-B-001',
        website: website_b,
        street_address: '456 Tenant B Ave'
      )
    end

    before do
      allow(Pwb::Current).to receive(:website).and_return(website_a)
    end

    describe 'POST /api_manage/v1/:locale/properties/:property_id/ai_description' do
      it 'denies generating description for another tenant property' do
        post "/api_manage/v1/en/properties/#{property_b.id}/ai_description",
             headers: {
               'HTTP_HOST' => 'tenant-a.example.com',
               'X-User-Email' => user_a.email
             }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'GET /api_manage/v1/:locale/properties/:property_id/ai_description/history' do
      it 'denies accessing history for another tenant property' do
        get "/api_manage/v1/en/properties/#{property_b.id}/ai_description/history",
            headers: {
              'HTTP_HOST' => 'tenant-a.example.com',
              'X-User-Email' => user_a.email
            }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'CMA Reports Isolation' do
    let!(:property_a) do
      Pwb::RealtyAsset.create!(
        reference: 'PROP-A-001',
        website: website_a,
        street_address: '123 Tenant A St'
      )
    end

    let!(:report_a) do
      Pwb::MarketReport.create!(
        website: website_a,
        report_type: 'cma',
        status: 'completed',
        title: 'CMA Report A'
      )
    end

    let!(:report_b) do
      Pwb::MarketReport.create!(
        website: website_b,
        report_type: 'cma',
        status: 'completed',
        title: 'CMA Report B'
      )
    end

    before do
      allow(Pwb::Current).to receive(:website).and_return(website_a)
    end

    describe 'GET /api_manage/v1/:locale/reports/cmas' do
      it 'only returns reports for current tenant' do
        get '/api_manage/v1/en/reports/cmas',
            headers: {
              'HTTP_HOST' => 'tenant-a.example.com',
              'X-User-Email' => user_a.email
            }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        report_ids = json['reports'].map { |r| r['id'] }
        expect(report_ids).to include(report_a.id)
        expect(report_ids).not_to include(report_b.id)
      end
    end

    describe 'GET /api_manage/v1/:locale/reports/cmas/:id' do
      it 'allows access to own report' do
        get "/api_manage/v1/en/reports/cmas/#{report_a.id}",
            headers: {
              'HTTP_HOST' => 'tenant-a.example.com',
              'X-User-Email' => user_a.email
            }

        expect(response).to have_http_status(:ok)
      end

      it 'denies access to another tenant report' do
        get "/api_manage/v1/en/reports/cmas/#{report_b.id}",
            headers: {
              'HTTP_HOST' => 'tenant-a.example.com',
              'X-User-Email' => user_a.email
            }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'DELETE /api_manage/v1/:locale/reports/cmas/:id' do
      it 'prevents deleting another tenant report' do
        expect {
          delete "/api_manage/v1/en/reports/cmas/#{report_b.id}",
                 headers: {
                   'HTTP_HOST' => 'tenant-a.example.com',
                   'X-User-Email' => user_a.email
                 }
        }.not_to change(Pwb::MarketReport, :count)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'Social Posts Isolation' do
    let!(:property_a) do
      Pwb::RealtyAsset.create!(
        reference: 'PROP-A-001',
        website: website_a,
        street_address: '123 Tenant A St'
      )
    end

    let!(:post_a) do
      Pwb::SocialMediaPost.create!(
        website: website_a,
        postable: property_a,
        platform: 'instagram',
        post_type: 'feed',
        caption: 'Post A'
      )
    end

    let!(:post_b) do
      property_b = Pwb::RealtyAsset.create!(
        reference: 'PROP-B-001',
        website: website_b,
        street_address: '456 Tenant B Ave'
      )
      Pwb::SocialMediaPost.create!(
        website: website_b,
        postable: property_b,
        platform: 'instagram',
        post_type: 'feed',
        caption: 'Post B'
      )
    end

    before do
      allow(Pwb::Current).to receive(:website).and_return(website_a)
    end

    describe 'GET /api_manage/v1/:locale/ai/social_posts' do
      it 'only returns posts for current tenant' do
        get '/api_manage/v1/en/ai/social_posts',
            headers: {
              'HTTP_HOST' => 'tenant-a.example.com',
              'X-User-Email' => user_a.email
            }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        post_ids = json['posts'].map { |p| p['id'] }
        expect(post_ids).to include(post_a.id)
        expect(post_ids).not_to include(post_b.id)
      end
    end

    describe 'GET /api_manage/v1/:locale/ai/social_posts/:id' do
      it 'allows access to own post' do
        get "/api_manage/v1/en/ai/social_posts/#{post_a.id}",
            headers: {
              'HTTP_HOST' => 'tenant-a.example.com',
              'X-User-Email' => user_a.email
            }

        expect(response).to have_http_status(:ok)
      end

      it 'denies access to another tenant post' do
        get "/api_manage/v1/en/ai/social_posts/#{post_b.id}",
            headers: {
              'HTTP_HOST' => 'tenant-a.example.com',
              'X-User-Email' => user_a.email
            }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'DELETE /api_manage/v1/:locale/ai/social_posts/:id' do
      it 'prevents deleting another tenant post' do
        expect {
          delete "/api_manage/v1/en/ai/social_posts/#{post_b.id}",
                 headers: {
                   'HTTP_HOST' => 'tenant-a.example.com',
                   'X-User-Email' => user_a.email
                 }
        }.not_to change(Pwb::SocialMediaPost, :count)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'ID Manipulation Attacks' do
    let!(:page_a) { Pwb::Page.create!(slug: 'page-a', website_id: website_a.id) }
    let!(:page_b) { Pwb::Page.create!(slug: 'page-b', website_id: website_b.id) }

    before do
      allow(Pwb::Current).to receive(:website).and_return(website_a)
    end

    it 'prevents accessing another tenant resource by guessing ID' do
      # Try to access page_b (ID from tenant B) while authenticated as tenant A
      get "/api_manage/v1/en/pages/#{page_b.id}",
          headers: { 'HTTP_HOST' => 'tenant-a.example.com', 'X-User-Email' => user_a.email }

      expect(response).to have_http_status(:not_found)
    end

    it 'prevents updating another tenant resource by ID manipulation' do
      original_slug = page_b.slug

      patch "/api_manage/v1/en/pages/#{page_b.id}",
            params: { page: { slug: 'hacked' } },
            headers: { 'HTTP_HOST' => 'tenant-a.example.com', 'X-User-Email' => user_a.email }

      expect(response).to have_http_status(:not_found)
      expect(page_b.reload.slug).to eq(original_slug)
    end

    it 'prevents deleting another tenant resource by ID manipulation' do
      expect {
        delete "/api_manage/v1/en/pages/#{page_b.id}",
               headers: { 'HTTP_HOST' => 'tenant-a.example.com', 'X-User-Email' => user_a.email }
      }.not_to change(Pwb::Page, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
