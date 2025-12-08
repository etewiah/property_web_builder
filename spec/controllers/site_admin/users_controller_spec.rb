# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::UsersController, type: :controller do
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
    let!(:user_own) { create(:pwb_user, website: website, email: 'own@test.com') }
    let!(:user_other) { create(:pwb_user, website: other_website, email: 'other@test.com') }

    it 'returns success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'only includes users from the current website' do
      get :index

      users = assigns(:users)
      expect(users).to include(user)
      expect(users).to include(user_own)
      expect(users).not_to include(user_other)
    end

    it 'all returned users belong to current website' do
      3.times do |i|
        create(:pwb_user, website: website, email: "test#{i}@own.com")
        create(:pwb_user, website: other_website, email: "test#{i}@other.com")
      end

      get :index

      users = assigns(:users)
      expect(users.pluck(:website_id).uniq).to eq([website.id])
    end

    describe 'search functionality' do
      let!(:searchable_user) { create(:pwb_user, website: website, email: 'searchable@own.com') }
      let!(:other_searchable_user) { create(:pwb_user, website: other_website, email: 'searchable@other.com') }

      it 'searches only within current website users' do
        get :index, params: { search: 'searchable' }

        users = assigns(:users)
        expect(users).to include(searchable_user)
        expect(users).not_to include(other_searchable_user)
      end
    end
  end

  describe 'GET #show' do
    let!(:user_own) { create(:pwb_user, website: website, email: 'own@test.com') }
    let!(:user_other) { create(:pwb_user, website: other_website, email: 'other@test.com') }

    it 'allows viewing own website user' do
      get :show, params: { id: user_own.id }

      expect(response).to have_http_status(:success)
      expect(assigns(:user)).to eq(user_own)
    end

    it 'returns 404 for other website user' do
      get :show, params: { id: user_other.id }

      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('site_admin/shared/record_not_found')
    end

    it 'returns 404 for non-existent user' do
      get :show, params: { id: SecureRandom.uuid }

      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('site_admin/shared/record_not_found')
    end
  end

  describe 'authentication' do
    context 'when user is not signed in' do
      before { sign_out :user }

      it 'denies access' do
        get :index
        # May redirect to sign in or return 403 forbidden depending on auth configuration
        expect(response).to redirect_to(new_user_session_path(locale: :en)).or have_http_status(:forbidden)
      end
    end
  end
end
