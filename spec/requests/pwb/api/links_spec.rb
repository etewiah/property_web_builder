# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe 'Links API', type: :request do
    include Warden::Test::Helpers
    include FactoryBot::Syntax::Methods

    before do
      Warden.test_mode!
      Pwb::Current.reset
    end

    after do
      Warden.test_reset!
    end

    let!(:website) { create(:pwb_website, subdomain: 'links-api-test') }
    let!(:admin_user) { create(:pwb_user, :admin, website: website) }

    let(:request_headers) do
      {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    end

    describe 'GET /api/v1/links' do
      let!(:top_nav_link) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_link, :top_nav, website: website, page_slug: 'about')
        end
      end

      let!(:footer_link) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_link, :footer, website: website, page_slug: 'contact')
        end
      end

      before do
        login_as admin_user, scope: :user
      end

      it 'returns links grouped by type' do
        host! 'links-api-test.example.com'
        get '/api/v1/links', headers: request_headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json).to have_key('top_nav_links')
        expect(json).to have_key('footer_links')
      end

      it 'supports locale parameter' do
        host! 'links-api-test.example.com'
        get '/api/v1/links', params: { locale: 'es' }, headers: request_headers

        expect(response).to have_http_status(:success)
      end

      it 'isolates links by tenant' do
        other_website = create(:pwb_website, subdomain: 'other-links')
        other_link = ActsAsTenant.with_tenant(other_website) do
          create(:pwb_link, :top_nav, website: other_website, page_slug: 'other-page')
        end

        host! 'links-api-test.example.com'
        get '/api/v1/links', headers: request_headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Should not include links from other tenant
        all_links = json['top_nav_links'] + json['footer_links']
        expect(all_links.map { |l| l['id'] }).not_to include(other_link.id)
      end
    end

    describe 'POST /api/v1/links/bulk_update' do
      let!(:nav_link) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_link, :top_nav, website: website, page_slug: 'nav-page', visible: true)
        end
      end

      let!(:footer_link) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_link, :footer, website: website, page_slug: 'footer-page', visible: true)
        end
      end

      before do
        login_as admin_user, scope: :user
      end

      it 'updates multiple links at once' do
        host! 'links-api-test.example.com'

        link_groups = {
          linkGroups: {
            top_nav_links: [{ slug: nav_link.slug, visible: false }],
            footer_links: [{ slug: footer_link.slug, visible: false }]
          }.to_json
        }

        post '/api/v1/links/bulk_update', params: link_groups, headers: request_headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['success']).to eq(true)
      end

      it 'does not update links from other tenants' do
        other_website = create(:pwb_website, subdomain: 'other-bulk')
        other_link = ActsAsTenant.with_tenant(other_website) do
          create(:pwb_link, :top_nav, website: other_website, page_slug: 'other-nav', visible: true)
        end

        host! 'links-api-test.example.com'

        # Attempt to update other tenant's link
        link_groups = {
          linkGroups: {
            top_nav_links: [{ slug: other_link.slug, visible: false }],
            footer_links: []
          }.to_json
        }

        post '/api/v1/links/bulk_update', params: link_groups, headers: request_headers

        # The other link should not be updated
        other_link.reload
        expect(other_link.visible).to be_truthy
      end
    end
  end
end
