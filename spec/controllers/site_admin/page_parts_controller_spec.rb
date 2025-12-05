# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::PagePartsController, type: :controller do
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
    let!(:page_part_own) do
      Pwb::PagePart.create!(
        page_part_key: 'own_part',
        page_slug: 'home',
        website_id: website.id
      )
    end

    let!(:page_part_other) do
      Pwb::PagePart.create!(
        page_part_key: 'other_part',
        page_slug: 'home',
        website_id: other_website.id
      )
    end

    it 'returns success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'only includes page_parts from the current website' do
      get :index

      page_parts = assigns(:page_parts)
      expect(page_parts).to include(page_part_own)
      expect(page_parts).not_to include(page_part_other)
    end

    it 'all returned page_parts belong to current website' do
      3.times do |i|
        Pwb::PagePart.create!(page_part_key: "own_#{i}", page_slug: 'test', website_id: website.id)
        Pwb::PagePart.create!(page_part_key: "other_#{i}", page_slug: 'test', website_id: other_website.id)
      end

      get :index

      page_parts = assigns(:page_parts)
      expect(page_parts.pluck(:website_id).uniq).to eq([website.id])
    end

    describe 'search functionality' do
      let!(:searchable_part) do
        Pwb::PagePart.create!(
          page_part_key: 'searchable_part',
          page_slug: 'home',
          website_id: website.id
        )
      end

      let!(:other_searchable_part) do
        Pwb::PagePart.create!(
          page_part_key: 'searchable_part',
          page_slug: 'home',
          website_id: other_website.id
        )
      end

      it 'searches only within current website page_parts' do
        get :index, params: { search: 'searchable' }

        page_parts = assigns(:page_parts)
        expect(page_parts).to include(searchable_part)
        expect(page_parts).not_to include(other_searchable_part)
      end
    end
  end

  describe 'GET #show' do
    let!(:page_part_own) do
      Pwb::PagePart.create!(page_part_key: 'own_part', page_slug: 'home', website_id: website.id)
    end

    let!(:page_part_other) do
      Pwb::PagePart.create!(page_part_key: 'other_part', page_slug: 'home', website_id: other_website.id)
    end

    it 'allows viewing own website page_part' do
      get :show, params: { id: page_part_own.id }

      expect(response).to have_http_status(:success)
      expect(assigns(:page_part)).to eq(page_part_own)
    end

    it 'raises RecordNotFound for other website page_part' do
      expect {
        get :show, params: { id: page_part_other.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
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
