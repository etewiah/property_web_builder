# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe 'Pages API', type: :request do
    include Warden::Test::Helpers
    include FactoryBot::Syntax::Methods

    before do
      Warden.test_mode!
      Pwb::Current.reset
    end

    after do
      Warden.test_reset!
    end

    let!(:website) { create(:pwb_website, subdomain: 'pages-test') }
    let!(:admin_user) { create(:pwb_user, :admin) }

    let(:request_headers) do
      {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    end

    describe 'GET /api/v1/pages/:page_name' do
      let!(:page) { create(:page_with_content_html_page_part, slug: 'about', website: website) }

      context 'with signed in admin user' do
        before do
          login_as admin_user, scope: :user
        end

        it 'returns page details for the current tenant' do
          host! 'pages-test.example.com'
          get '/api/v1/pages/about'

          expect(response).to have_http_status(:success)
        end
      end

      context 'without signed in user' do
        it 'redirects to sign_in page' do
          host! 'pages-test.example.com'
          get '/api/v1/pages/about'

          expect(response).to have_http_status(:redirect)
        end
      end
    end

    describe 'PUT /api/v1/pages/page_part_visibility' do
      let!(:page) { create(:page_with_content_html_page_part, slug: 'home', website: website) }

      before do
        login_as admin_user, scope: :user
      end

      it 'sets page_part visibility correctly' do
        host! 'pages-test.example.com'

        target_page_content = page.page_contents.find_by_page_part_key('content_html')
        expect(target_page_content).to be_present

        put '/api/v1/pages/page_part_visibility', params: {
          page_slug: 'home',
          cmd: 'setAsHidden',
          page_part_key: 'content_html'
        }

        expect(response).to have_http_status(:success)
        target_page_content.reload
        expect(target_page_content.visible_on_page).to eq(false)

        put '/api/v1/pages/page_part_visibility', params: {
          page_slug: 'home',
          cmd: 'setAsVisible',
          page_part_key: 'content_html'
        }

        expect(response).to have_http_status(:success)
        target_page_content.reload
        expect(target_page_content.visible_on_page).to eq(true)
      end
    end

    describe 'multi-tenant page isolation' do
      let!(:website1) { create(:pwb_website, subdomain: 'pages-tenant1') }
      let!(:website2) { create(:pwb_website, subdomain: 'pages-tenant2') }
      let!(:page1) { create(:pwb_page, slug: 'about', website: website1, visible: true) }
      let!(:page2) { create(:pwb_page, slug: 'about', website: website2, visible: true) }

      before do
        login_as admin_user, scope: :user
      end

      it 'returns pages for each tenant' do
        # Verify each website has its own pages
        expect(page1.website).to eq(website1)
        expect(page2.website).to eq(website2)

        # Both have 'about' slug but belong to different websites
        expect(page1.slug).to eq('about')
        expect(page2.slug).to eq('about')
        expect(page1.id).not_to eq(page2.id)

        # Verify scoped queries work
        expect(website1.pages.find_by(slug: 'about')).to eq(page1)
        expect(website2.pages.find_by(slug: 'about')).to eq(page2)
      end

      it 'isolates page access between tenants' do
        # Create a page only on tenant1
        unique_page = create(:pwb_page, slug: 'unique-page', website: website1, visible: true)

        # Verify the page belongs to website1
        expect(unique_page.website).to eq(website1)

        # Verify website1 can find the page
        expect(website1.pages.find_by(slug: 'unique-page')).to eq(unique_page)

        # Verify website2 cannot find the page
        expect(website2.pages.find_by(slug: 'unique-page')).to be_nil

        # Verify using Pwb::Current
        Pwb::Current.website = website1
        expect(Pwb::Current.website.pages.find_by(slug: 'unique-page')).to eq(unique_page)

        Pwb::Current.reset
        Pwb::Current.website = website2
        expect(Pwb::Current.website.pages.find_by(slug: 'unique-page')).to be_nil
      end
    end
  end
end
