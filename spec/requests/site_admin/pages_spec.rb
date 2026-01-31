# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::PagesController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'pages-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@pages-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/pages (index)' do
    it 'renders the pages list successfully' do
      get site_admin_pages_path, headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'with pages' do
      let!(:page1) { create(:pwb_page, website: website, slug: 'about-us') }
      let!(:page2) { create(:pwb_page, website: website, slug: 'services') }

      it 'displays pages in the list' do
        get site_admin_pages_path, headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('about-us')
        expect(response.body).to include('services')
      end

      it 'supports search functionality' do
        get site_admin_pages_path,
            params: { search: 'about' },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('about-us')
      end
    end
  end

  describe 'GET /site_admin/pages/:id (show)' do
    let!(:page) { create(:pwb_page, website: website, slug: 'test-page') }

    it 'renders the page show view' do
      get site_admin_page_path(page),
          headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /site_admin/pages/:id/edit' do
    let!(:page) { create(:pwb_page, website: website, slug: 'edit-page') }

    it 'renders the edit form' do
      get edit_site_admin_page_path(page),
          headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /site_admin/pages/:id (update)' do
    let!(:page) { create(:pwb_page, website: website, slug: 'update-page', visible: false) }

    it 'updates the page successfully' do
      patch site_admin_page_path(page),
            params: { pwb_page: { visible: true, show_in_top_nav: true } },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      page.reload
      expect(page.visible).to be true
      expect(page.show_in_top_nav).to be true
    end

    it 'redirects to show page after update' do
      patch site_admin_page_path(page),
            params: { pwb_page: { visible: true } },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to redirect_to(site_admin_page_path(page))
      expect(flash[:notice]).to include('successfully updated')
    end
  end

  describe 'GET /site_admin/pages/:id/settings' do
    let!(:page) { create(:pwb_page, website: website, slug: 'settings-page') }

    it 'renders the settings form' do
      get settings_site_admin_page_path(page),
          headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /site_admin/pages/:id/settings (update_settings)' do
    let!(:page) { create(:pwb_page, website: website, slug: 'settings-update') }

    it 'updates page settings' do
      patch settings_site_admin_page_path(page),
            params: {
              pwb_page: {
                seo_title: 'New SEO Title',
                meta_description: 'New meta description',
                show_in_footer: true
              }
            },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      page.reload
      expect(page.seo_title).to eq('New SEO Title')
      expect(page.meta_description).to eq('New meta description')
      expect(page.show_in_footer).to be true
    end

    it 'redirects to settings page after update' do
      patch settings_site_admin_page_path(page),
            params: { pwb_page: { seo_title: 'Updated' } },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to redirect_to(settings_site_admin_page_path(page))
      expect(flash[:notice]).to include('successfully updated')
    end
  end

  describe 'PATCH /site_admin/pages/:id/reorder_parts' do
    let!(:page) { create(:pwb_page, website: website, slug: 'reorder-page') }
    let!(:part1) { create(:pwb_page_part, page: page, website: website, order_in_editor: 0, show_in_editor: true) }
    let!(:part2) { create(:pwb_page_part, page: page, website: website, order_in_editor: 1, show_in_editor: true) }
    let!(:part3) { create(:pwb_page_part, page: page, website: website, order_in_editor: 2, show_in_editor: true) }

    it 'reorders page parts' do
      patch reorder_parts_site_admin_page_path(page),
            params: { part_ids: [part3.id, part1.id, part2.id] },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:ok)

      part1.reload
      part2.reload
      part3.reload

      expect(part3.order_in_editor).to eq(0)
      expect(part1.order_in_editor).to eq(1)
      expect(part2.order_in_editor).to eq(2)
    end

    it 'only reorders parts belonging to the page' do
      other_website = create(:pwb_website, subdomain: 'other-reorder')
      create(:pwb_agency, website: other_website)
      other_page = create(:pwb_page, website: other_website, slug: 'other')
      other_part = create(:pwb_page_part, page: other_page, website: other_website, order_in_editor: 0)

      original_order = other_part.order_in_editor

      patch reorder_parts_site_admin_page_path(page),
            params: { part_ids: [other_part.id, part1.id] },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      other_part.reload
      expect(other_part.order_in_editor).to eq(original_order)
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
      page = create(:pwb_page, website: website, slug: 'auth-test')

      get site_admin_page_path(page),
          headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on update' do
      page = create(:pwb_page, website: website, slug: 'auth-update')

      patch site_admin_page_path(page),
            params: { pwb_page: { visible: true } },
            headers: { 'HTTP_HOST' => 'pages-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
