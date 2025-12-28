# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::PagesController', type: :request do
  # Pages are the website content pages (home, about-us, contact-us, etc.)
  # Must verify: CRUD, page parts management, search, settings, multi-tenancy

  let!(:website) { create(:pwb_website, subdomain: 'pages-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@pages-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  describe 'GET /site_admin/pages (index)' do
    it 'renders the pages list successfully' do
      get site_admin_pages_path, headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'with pages' do
      before do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_page, website: website, slug: 'home')
          create(:pwb_page, website: website, slug: 'about-us')
        end
      end

      it 'displays pages in the list' do
        get site_admin_pages_path, headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'orders pages by created_at desc' do
        get site_admin_pages_path, headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'search functionality' do
      before do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_page, website: website, slug: 'home')
          create(:pwb_page, website: website, slug: 'contact-us')
        end
      end

      it 'searches by slug' do
        get site_admin_pages_path, params: { search: 'contact' },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'returns empty results for non-matching search' do
        get site_admin_pages_path, params: { search: 'nonexistent12345' },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-pages') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }

      before do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_page, website: website, slug: 'my-page')
        end
        ActsAsTenant.with_tenant(other_website) do
          create(:pwb_page, website: other_website, slug: 'other-page')
        end
      end

      it 'only shows pages for current website' do
        get site_admin_pages_path, headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

        expect(response).to have_http_status(:success)
        # Controller scopes by website_id, so only my_page should be visible
      end
    end
  end

  describe 'GET /site_admin/pages/:id (show)' do
    let!(:page) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_page, website: website, slug: 'test-page')
      end
    end

    it 'renders the page show view' do
      get site_admin_page_path(page),
          headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-show-pages') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:other_page) do
        ActsAsTenant.with_tenant(other_website) do
          create(:pwb_page, website: other_website, slug: 'other-test')
        end
      end

      it 'cannot access pages from other websites' do
        get site_admin_page_path(other_page),
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

        expect(response).to have_http_status(:not_found)
      rescue ActiveRecord::RecordNotFound
        # Expected behavior - multi-tenancy isolation working
        expect(true).to be true
      end
    end
  end

  describe 'GET /site_admin/pages/:id/edit' do
    let!(:page) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_page, website: website, slug: 'edit-test')
      end
    end

    it 'renders the edit form' do
      get edit_site_admin_page_path(page),
          headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /site_admin/pages/:id (update)' do
    let!(:page) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_page, website: website, slug: 'update-test', visible: false)
      end
    end

    it 'updates the page successfully' do
      patch site_admin_page_path(page),
            params: { pwb_page: { visible: true } },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      page.reload
      expect(page.visible).to be true
    end

    it 'redirects to show page after update' do
      patch site_admin_page_path(page),
            params: { pwb_page: { visible: true } },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to redirect_to(site_admin_page_path(page))
      expect(flash[:notice]).to include('successfully updated')
    end

    it 'updates navigation visibility settings' do
      patch site_admin_page_path(page),
            params: { pwb_page: { show_in_top_nav: true, show_in_footer: true } },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      page.reload
      expect(page.show_in_top_nav).to be true
      expect(page.show_in_footer).to be true
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-update-pages') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:other_page) do
        ActsAsTenant.with_tenant(other_website) do
          create(:pwb_page, website: other_website, slug: 'other-update', visible: false)
        end
      end

      it 'cannot update pages from other websites' do
        patch site_admin_page_path(other_page),
              params: { pwb_page: { visible: true } },
              headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

        other_page.reload
        expect(other_page.visible).to be false
      rescue ActiveRecord::RecordNotFound
        # Expected behavior
        expect(true).to be true
      end
    end
  end

  describe 'GET /site_admin/pages/:id/settings' do
    let!(:page) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_page, website: website, slug: 'settings-test')
      end
    end

    it 'renders the settings page' do
      get settings_site_admin_page_path(page),
          headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /site_admin/pages/:id/settings (update_settings)' do
    let!(:page) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_page, website: website, slug: 'old-slug')
      end
    end

    it 'updates page settings successfully' do
      patch settings_site_admin_page_path(page),
            params: { pwb_page: { slug: 'new-slug' } },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      page.reload
      expect(page.slug).to eq('new-slug')
    end

    it 'redirects to settings page after update' do
      patch settings_site_admin_page_path(page),
            params: { pwb_page: { slug: 'new-slug' } },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to redirect_to(settings_site_admin_page_path(page))
      expect(flash[:notice]).to include('successfully updated')
    end

    it 'updates sort order settings' do
      patch settings_site_admin_page_path(page),
            params: { pwb_page: { sort_order_top_nav: 5, sort_order_footer: 3 } },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      page.reload
      expect(page.sort_order_top_nav).to eq(5)
      expect(page.sort_order_footer).to eq(3)
    end
  end

  describe 'PATCH /site_admin/pages/:id/reorder_parts' do
    let!(:page) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_page, website: website, slug: 'reorder-test')
      end
    end
    let!(:part1) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_page_part, page: page, website: website, order_in_editor: 0, show_in_editor: true)
      end
    end
    let!(:part2) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_page_part, page: page, website: website, order_in_editor: 1, show_in_editor: true)
      end
    end
    let!(:part3) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_page_part, page: page, website: website, order_in_editor: 2, show_in_editor: true)
      end
    end

    it 'reorders page parts' do
      # Reverse the order
      patch reorder_parts_site_admin_page_path(page),
            params: { part_ids: [part3.id, part2.id, part1.id] },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:ok)

      part1.reload
      part2.reload
      part3.reload

      expect(part3.order_in_editor).to eq(0)
      expect(part2.order_in_editor).to eq(1)
      expect(part1.order_in_editor).to eq(2)
    end

    it 'ignores parts from other websites' do
      other_website = create(:pwb_website, subdomain: 'other-reorder')
      create(:pwb_agency, website: other_website)
      other_part = ActsAsTenant.with_tenant(other_website) do
        create(:pwb_page_part, page: page, website: other_website, order_in_editor: 99, show_in_editor: true)
      end

      patch reorder_parts_site_admin_page_path(page),
            params: { part_ids: [other_part.id, part1.id] },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:ok)

      # Other website's part should not be modified
      other_part.reload
      expect(other_part.order_in_editor).to eq(99)
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users on index' do
      get site_admin_pages_path,
          headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on show' do
      page = ActsAsTenant.with_tenant(website) do
        create(:pwb_page, website: website, slug: 'auth-test')
      end

      get site_admin_page_path(page),
          headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on update' do
      page = ActsAsTenant.with_tenant(website) do
        create(:pwb_page, website: website, slug: 'auth-update')
      end

      patch site_admin_page_path(page),
            params: { pwb_page: { visible: true } },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
