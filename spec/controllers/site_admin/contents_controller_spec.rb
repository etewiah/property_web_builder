# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::ContentsController, type: :controller do
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
    let!(:content_own) do
      Pwb::Content.create!(
        key: 'own_content',
        tag: 'appearance',
        website_id: website.id
      )
    end

    let!(:content_other) do
      Pwb::Content.create!(
        key: 'other_content',
        tag: 'appearance',
        website_id: other_website.id
      )
    end

    it 'returns success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'only includes contents from the current website' do
      get :index

      contents = assigns(:contents)
      expect(contents).to include(content_own)
      expect(contents).not_to include(content_other)
    end

    it 'all returned contents belong to current website' do
      3.times do |i|
        Pwb::Content.create!(key: "own_#{i}", tag: 'test', website_id: website.id)
        Pwb::Content.create!(key: "other_#{i}", tag: 'test', website_id: other_website.id)
      end

      get :index

      contents = assigns(:contents)
      expect(contents.pluck(:website_id).uniq).to eq([website.id])
    end

    describe 'search functionality' do
      let!(:searchable_content) do
        Pwb::Content.create!(
          key: 'searchable_content',
          tag: 'searchable',
          website_id: website.id
        )
      end

      let!(:other_searchable_content) do
        Pwb::Content.create!(
          key: 'searchable_content',
          tag: 'searchable',
          website_id: other_website.id
        )
      end

      it 'searches only within current website contents' do
        get :index, params: { search: 'searchable' }

        contents = assigns(:contents)
        expect(contents).to include(searchable_content)
        expect(contents).not_to include(other_searchable_content)
      end
    end
  end

  describe 'GET #show' do
    let!(:content_own) do
      Pwb::Content.create!(key: 'own_content', tag: 'test', website_id: website.id)
    end

    let!(:content_other) do
      Pwb::Content.create!(key: 'other_content', tag: 'test', website_id: other_website.id)
    end

    it 'allows viewing own website content' do
      get :show, params: { id: content_own.id }

      expect(response).to have_http_status(:success)
      expect(assigns(:content)).to eq(content_own)
    end

    it 'raises RecordNotFound for other website content' do
      expect {
        get :show, params: { id: content_other.id }
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
