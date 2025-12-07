# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin Authorization', type: :controller do
  # Test authorization using the DashboardController as a representative
  controller(SiteAdminController) do
    def index
      render plain: 'OK'
    end
  end

  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:other_website) { create(:pwb_website, subdomain: 'other-site') }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    allow(Pwb::Current).to receive(:website).and_return(website)
    allow(controller).to receive(:current_website).and_return(website)
    routes.draw { get 'index' => 'site_admin#index' }
  end

  describe 'authentication requirement' do
    context 'when user is not signed in' do
      it 'renders forbidden page' do
        get :index
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'authorization by role' do
    context 'when user is owner for the website' do
      let(:user) { create(:pwb_user, website: website) }

      before do
        create(:pwb_user_membership, user: user, website: website, role: 'owner', active: true)
        sign_in user, scope: :user
      end

      it 'allows access' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is admin for the website' do
      let(:user) { create(:pwb_user, :admin, website: website) }

      before do
        sign_in user, scope: :user
      end

      it 'allows access' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is member (not admin) for the website' do
      let(:user) { create(:pwb_user, website: website) }

      before do
        create(:pwb_user_membership, user: user, website: website, role: 'member', active: true)
        sign_in user, scope: :user
      end

      it 'denies access with forbidden status' do
        get :index
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is viewer for the website' do
      let(:user) { create(:pwb_user, website: website) }

      before do
        create(:pwb_user_membership, user: user, website: website, role: 'viewer', active: true)
        sign_in user, scope: :user
      end

      it 'denies access with forbidden status' do
        get :index
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user has no membership for the website' do
      let(:user) { create(:pwb_user, website: other_website) }

      before do
        sign_in user, scope: :user
      end

      it 'denies access (redirects to login due to active_for_authentication? check)' do
        get :index
        # User without membership for current website fails active_for_authentication?
        # which causes redirect to login (firebase_login in this app)
        expect(response).to be_redirect
        expect(response.location).to include('firebase_login').or include('sign_in')
      end
    end

    context 'when user is admin for a DIFFERENT website' do
      let(:user) { create(:pwb_user, :admin, website: other_website) }

      before do
        sign_in user, scope: :user
      end

      it 'denies access (redirects to login due to active_for_authentication? check)' do
        get :index
        # Admin for different website fails active_for_authentication? for current website
        # which causes redirect to login (firebase_login in this app)
        expect(response).to be_redirect
        expect(response.location).to include('firebase_login').or include('sign_in')
      end

      it 'does not allow cross-tenant access' do
        get :index
        expect(response.body).not_to include('OK')
      end
    end

    context 'when user has inactive admin membership' do
      let(:user) { create(:pwb_user, website: website) }

      before do
        create(:pwb_user_membership, user: user, website: website, role: 'admin', active: false)
        sign_in user, scope: :user
      end

      it 'denies access with forbidden status' do
        get :index
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'bypass mechanism' do
    let(:user) { create(:pwb_user, website: website) }

    before do
      create(:pwb_user_membership, user: user, website: website, role: 'member', active: true)
      sign_in user, scope: :user
    end

    context 'when BYPASS_ADMIN_AUTH is set' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('BYPASS_ADMIN_AUTH', anything).and_return('true')
        allow(controller).to receive(:bypass_admin_auth?).and_return(true)
      end

      it 'allows access even for non-admin users' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end
  end
end
