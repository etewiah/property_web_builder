# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantAdmin::WebsitesController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:admin_user) { create(:pwb_user, email: 'admin@example.com', website: website) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
    sign_in admin_user, scope: :user
  end

  describe 'GET #index' do
    let!(:websites) { create_list(:pwb_website, 3) }

    it 'returns a successful response' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns @websites' do
      get :index
      expect(assigns(:websites)).to be_present
    end

    context 'with search parameter' do
      let!(:searchable_website) { create(:pwb_website, subdomain: 'searchable', company_display_name: 'Searchable Corp') }

      it 'searches by subdomain' do
        get :index, params: { search: 'searchable' }
        expect(assigns(:websites)).to include(searchable_website)
      end

      it 'searches by company_display_name' do
        get :index, params: { search: 'Searchable Corp' }
        expect(assigns(:websites)).to include(searchable_website)
      end
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { id: website.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the requested website' do
      get :show, params: { id: website.id }
      expect(assigns(:website)).to eq(website)
    end

    describe 'user counting' do
      # User counting is critical for tenant admin visibility.
      # Users can be associated with a website in two ways:
      # 1. Direct: User.website_id = website.id
      # 2. Membership: UserMembership(user_id, website_id)
      #
      # The count must include both without double-counting.

      let(:target_website) { create(:pwb_website, subdomain: 'target') }

      context 'with no users' do
        it 'sets @users_count to 0' do
          get :show, params: { id: target_website.id }
          expect(assigns(:users_count)).to eq(0)
        end
      end

      context 'with users via direct website_id association' do
        let!(:direct_user) { create(:pwb_user, website: target_website) }

        it 'counts users with direct website_id' do
          get :show, params: { id: target_website.id }
          expect(assigns(:users_count)).to eq(1)
        end

        context 'with multiple direct users' do
          let!(:direct_user2) { create(:pwb_user, website: target_website) }

          it 'counts all direct users' do
            get :show, params: { id: target_website.id }
            expect(assigns(:users_count)).to eq(2)
          end
        end
      end

      context 'with users via user_memberships' do
        let(:other_website) { create(:pwb_website, subdomain: 'other') }
        let!(:membership_user) { create(:pwb_user, website: other_website) }
        let!(:membership) { create(:pwb_user_membership, user: membership_user, website: target_website) }

        it 'counts users with memberships' do
          get :show, params: { id: target_website.id }
          expect(assigns(:users_count)).to eq(1)
        end
      end

      context 'with users via both associations' do
        let!(:direct_user) { create(:pwb_user, website: target_website) }
        let(:other_website) { create(:pwb_website, subdomain: 'other') }
        let!(:membership_user) { create(:pwb_user, website: other_website) }
        let!(:membership) { create(:pwb_user_membership, user: membership_user, website: target_website) }

        it 'counts both direct and membership users' do
          get :show, params: { id: target_website.id }
          expect(assigns(:users_count)).to eq(2)
        end
      end

      context 'when user has both direct association AND membership (edge case)' do
        # A user might have website_id = X AND also have a membership for website X.
        # This should NOT double-count the user.
        let!(:dual_user) { create(:pwb_user, website: target_website) }
        let!(:redundant_membership) { create(:pwb_user_membership, user: dual_user, website: target_website) }

        it 'does not double-count users with both associations' do
          get :show, params: { id: target_website.id }
          expect(assigns(:users_count)).to eq(1)
        end
      end
    end

    describe 'property counting' do
      let(:target_website) { create(:pwb_website, subdomain: 'target') }

      context 'with no properties' do
        it 'sets @props_count to 0' do
          get :show, params: { id: target_website.id }
          expect(assigns(:props_count)).to eq(0)
        end
      end

      context 'with properties' do
        before do
          # Create properties associated with the target website
          create_list(:pwb_realty_asset, 3, website: target_website)
        end

        it 'counts properties for the website' do
          get :show, params: { id: target_website.id }
          expect(assigns(:props_count)).to eq(3)
        end
      end
    end

    describe 'page counting' do
      let(:target_website) { create(:pwb_website, subdomain: 'target') }

      context 'with no pages' do
        it 'sets @pages_count to 0' do
          get :show, params: { id: target_website.id }
          expect(assigns(:pages_count)).to eq(0)
        end
      end
    end

    describe 'message counting' do
      let(:target_website) { create(:pwb_website, subdomain: 'target') }

      context 'with no messages' do
        it 'sets @messages_count to 0' do
          get :show, params: { id: target_website.id }
          expect(assigns(:messages_count)).to eq(0)
        end
      end

      context 'with messages' do
        before do
          create_list(:pwb_message, 2, website: target_website)
        end

        it 'counts messages for the website' do
          get :show, params: { id: target_website.id }
          expect(assigns(:messages_count)).to eq(2)
        end
      end
    end
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new
      expect(response).to have_http_status(:success)
    end

    it 'assigns a new website' do
      get :new
      expect(assigns(:website)).to be_a_new(Pwb::Website)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        website: {
          subdomain: 'new-website',
          company_display_name: 'New Company',
          theme_name: 'default'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new website' do
        expect do
          post :create, params: valid_params
        end.to change(Pwb::Website, :count).by(1)
      end

      it 'redirects to the created website' do
        post :create, params: valid_params
        expect(response).to redirect_to(tenant_admin_website_path(Pwb::Website.last))
      end
    end
  end

  describe 'GET #edit' do
    it 'returns a successful response' do
      get :edit, params: { id: website.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the requested website' do
      get :edit, params: { id: website.id }
      expect(assigns(:website)).to eq(website)
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the website' do
      website_to_delete = create(:pwb_website, subdomain: 'to-delete')
      expect do
        delete :destroy, params: { id: website_to_delete.id }
      end.to change(Pwb::Website, :count).by(-1)
    end

    it 'redirects to websites index' do
      delete :destroy, params: { id: website.id }
      expect(response).to redirect_to(tenant_admin_websites_path)
    end
  end

  describe 'authorization' do
    context 'when user is not a tenant admin' do
      let(:regular_user) { create(:pwb_user, email: 'user@example.com', website: website) }

      before do
        sign_in regular_user, scope: :user
      end

      it 'denies access to index' do
        get :index
        expect(response).to have_http_status(:forbidden)
      end

      it 'denies access to show' do
        get :show, params: { id: website.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe '#count_website_users (private method)' do
    # Testing the private method indirectly through controller behavior
    # to ensure the SQL query handles edge cases correctly

    let(:target_website) { create(:pwb_website, subdomain: 'target') }
    let(:other_website) { create(:pwb_website, subdomain: 'other') }

    it 'returns 0 for website with no users' do
      get :show, params: { id: target_website.id }
      expect(assigns(:users_count)).to eq(0)
    end

    it 'correctly counts users across multiple websites without cross-contamination' do
      # Create users for target website
      create(:pwb_user, website: target_website)

      # Create users for other website (should not be counted)
      create(:pwb_user, website: other_website)

      get :show, params: { id: target_website.id }
      expect(assigns(:users_count)).to eq(1)
    end
  end
end
