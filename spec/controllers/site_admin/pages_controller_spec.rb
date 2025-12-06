# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::PagesController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:other_website) { create(:pwb_website, subdomain: 'other-site') }
  let(:user) { create(:pwb_user, :admin, website: website) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user, scope: :user
    allow(Pwb::Current).to receive(:website).and_return(website)
    allow(controller).to receive(:current_website).and_return(website)
  end

  describe 'GET #index' do
    let!(:page_own) do
      Pwb::Page.create!(slug: 'own-page', visible: true, website_id: website.id)
    end

    let!(:page_other) do
      Pwb::Page.create!(slug: 'other-page', visible: true, website_id: other_website.id)
    end

    it 'returns success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'only includes pages from the current website' do
      get :index

      pages = assigns(:pages)
      expect(pages).to include(page_own)
      expect(pages).not_to include(page_other)
    end

    it 'all returned pages belong to current website' do
      3.times do |i|
        Pwb::Page.create!(slug: "page-own-#{i}", website_id: website.id)
        Pwb::Page.create!(slug: "page-other-#{i}", website_id: other_website.id)
      end

      get :index

      pages = assigns(:pages)
      expect(pages.pluck(:website_id).uniq).to eq([website.id])
    end

    describe 'search functionality' do
      let!(:searchable_page) do
        Pwb::Page.create!(slug: 'searchable-page', website_id: website.id)
      end

      let!(:other_searchable_page) do
        Pwb::Page.create!(slug: 'searchable-page', website_id: other_website.id)
      end

      it 'searches only within current website pages' do
        get :index, params: { search: 'searchable' }

        pages = assigns(:pages)
        expect(pages).to include(searchable_page)
        expect(pages).not_to include(other_searchable_page)
      end
    end
  end

  describe 'GET #show' do
    let!(:page_own) { Pwb::Page.create!(slug: 'own-page', website_id: website.id) }
    let!(:page_other) { Pwb::Page.create!(slug: 'other-page', website_id: other_website.id) }

    it 'allows viewing own website page' do
      get :show, params: { id: page_own.id }

      expect(response).to have_http_status(:success)
      expect(assigns(:page)).to eq(page_own)
    end

    it 'returns 404 for other website page' do
      get :show, params: { id: page_other.id }

      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('site_admin/shared/record_not_found')
    end

    it 'returns 404 for non-existent page' do
      get :show, params: { id: SecureRandom.uuid }

      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('site_admin/shared/record_not_found')
    end
  end

  describe 'GET #edit' do
    let!(:page_own) { Pwb::Page.create!(slug: 'own-page', website_id: website.id) }
    let!(:page_other) { Pwb::Page.create!(slug: 'other-page', website_id: other_website.id) }

    it 'allows editing own website page' do
      get :edit, params: { id: page_own.id }

      expect(response).to have_http_status(:success)
      expect(assigns(:page)).to eq(page_own)
    end

    it 'returns 404 for other website page' do
      get :edit, params: { id: page_other.id }

      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('site_admin/shared/record_not_found')
    end
  end

  describe 'PATCH #update' do
    let!(:page_own) { Pwb::Page.create!(slug: 'own-page', visible: true, website_id: website.id) }
    let!(:page_other) { Pwb::Page.create!(slug: 'other-page', visible: true, website_id: other_website.id) }

    it 'allows updating own website page' do
      patch :update, params: { id: page_own.id, pwb_page: { visible: false } }

      expect(response).to redirect_to(site_admin_page_path(page_own))
      expect(page_own.reload.visible).to be false
    end

    it 'returns 404 when trying to update other website page' do
      original_visibility = page_other.visible

      patch :update, params: { id: page_other.id, pwb_page: { visible: false } }

      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('site_admin/shared/record_not_found')
      # Verify page was not modified
      expect(page_other.reload.visible).to eq(original_visibility)
    end
  end

  describe 'authentication' do
    context 'when user is not signed in' do
      before { sign_out :user }

      it 'redirects to sign in page' do
        get :index
        expect(response).to redirect_to(new_user_session_path(locale: :en))
      end
    end
  end
end
