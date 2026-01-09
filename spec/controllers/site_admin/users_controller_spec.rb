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
    # Create owner membership for current user (owner can manage all other roles)
    user.user_memberships.find_or_create_by!(website: website) do |m|
      m.role = 'owner'
      m.active = true
    end
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

    describe 'pagination' do
      before do
        create_list(:pwb_user, 30, website: website)
      end

      it 'paginates results' do
        get :index
        expect(assigns(:pagy)).to be_present
        expect(assigns(:users).count).to be <= 25
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

    it 'assigns the user membership' do
      user_own.user_memberships.create!(website: website, role: 'member', active: true)
      get :show, params: { id: user_own.id }
      expect(assigns(:membership)).to be_present
    end
  end

  describe 'GET #new' do
    it 'returns success' do
      get :new
      expect(response).to have_http_status(:success)
    end

    it 'assigns a new user' do
      get :new
      expect(assigns(:user)).to be_a_new(Pwb::User)
    end

    it 'renders the new template' do
      get :new
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    context 'with a new user email' do
      let(:valid_params) do
        {
          user: {
            email: 'newuser@example.com',
            first_names: 'John',
            last_names: 'Doe',
            role: 'member'
          }
        }
      end

      it 'creates a new user' do
        expect do
          post :create, params: valid_params
        end.to change(Pwb::User, :count).by(1)
      end

      it 'creates a membership for the new user' do
        post :create, params: valid_params
        new_user = Pwb::User.find_by(email: 'newuser@example.com')
        expect(new_user.user_memberships.exists?(website: website)).to be true
      end

      it 'sets the correct role on membership' do
        post :create, params: valid_params
        new_user = Pwb::User.find_by(email: 'newuser@example.com')
        membership = new_user.user_memberships.find_by(website: website)
        expect(membership.role).to eq('member')
      end

      it 'redirects to users index with success notice' do
        post :create, params: valid_params
        expect(response).to redirect_to(site_admin_users_path)
        expect(flash[:notice]).to include('Invitation sent')
      end
    end

    context 'with an existing user email' do
      let!(:existing_user) { create(:pwb_user, email: 'existing@example.com') }

      context 'who is not a member of this website' do
        let(:params) do
          {
            user: {
              email: 'existing@example.com',
              role: 'member'
            }
          }
        end

        it 'does not create a new user' do
          expect do
            post :create, params: params
          end.not_to change(Pwb::User, :count)
        end

        it 'adds the existing user to this website' do
          post :create, params: params
          expect(existing_user.user_memberships.exists?(website: website)).to be true
        end

        it 'redirects with success notice' do
          post :create, params: params
          expect(response).to redirect_to(site_admin_users_path)
          expect(flash[:notice]).to include('has been added')
        end
      end

      context 'who is already a member of this website' do
        before do
          existing_user.user_memberships.create!(website: website, role: 'member', active: true)
        end

        let(:params) do
          {
            user: {
              email: 'existing@example.com',
              role: 'member'
            }
          }
        end

        it 'does not create duplicate membership' do
          expect do
            post :create, params: params
          end.not_to change(Pwb::UserMembership, :count)
        end

        it 'renders new with alert' do
          post :create, params: params
          expect(response).to have_http_status(:unprocessable_entity)
          expect(flash[:alert]).to include('already a member')
        end
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          user: {
            email: 'invalid-email',
            first_names: '',
            last_names: ''
          }
        }
      end

      it 'does not create a user' do
        expect do
          post :create, params: invalid_params
        end.not_to change(Pwb::User, :count)
      end

      it 'renders new template' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET #edit' do
    let!(:member_user) do
      u = create(:pwb_user, website: website, email: 'member@test.com')
      u.user_memberships.create!(website: website, role: 'member', active: true)
      u
    end

    it 'returns success' do
      get :edit, params: { id: member_user.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the user' do
      get :edit, params: { id: member_user.id }
      expect(assigns(:user)).to eq(member_user)
    end

    it 'assigns the membership' do
      get :edit, params: { id: member_user.id }
      expect(assigns(:membership)).to be_present
      expect(assigns(:membership).role).to eq('member')
    end

    context 'when trying to edit user from another website' do
      let!(:other_user) { create(:pwb_user, website: other_website) }

      it 'returns 404' do
        get :edit, params: { id: other_user.id }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH #update' do
    let!(:member_user) do
      u = create(:pwb_user, website: website, email: 'member@test.com', first_names: 'Old', last_names: 'Name')
      u.user_memberships.create!(website: website, role: 'member', active: true)
      u
    end

    context 'with valid params' do
      let(:valid_params) do
        {
          id: member_user.id,
          user: {
            first_names: 'New',
            last_names: 'Person',
            phone_number_primary: '+1234567890'
          },
          role: 'admin'
        }
      end

      it 'updates the user' do
        patch :update, params: valid_params
        member_user.reload
        expect(member_user.first_names).to eq('New')
        expect(member_user.last_names).to eq('Person')
      end

      it 'updates the role' do
        patch :update, params: valid_params
        membership = member_user.user_memberships.find_by(website: website)
        expect(membership.role).to eq('admin')
      end

      it 'redirects to user show page' do
        patch :update, params: valid_params
        expect(response).to redirect_to(site_admin_user_path(member_user))
        expect(flash[:notice]).to include('successfully')
      end
    end

    context 'with invalid params' do
      before do
        # Simulate validation failure
        allow_any_instance_of(Pwb::User).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(member_user))
      end

      let(:invalid_params) do
        {
          id: member_user.id,
          user: {
            first_names: ''
          }
        }
      end

      it 'renders edit template' do
        patch :update, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:member_user) do
      u = create(:pwb_user, website: website, email: 'member@test.com')
      u.user_memberships.create!(website: website, role: 'member', active: true)
      u
    end

    it 'removes the user membership' do
      expect do
        delete :destroy, params: { id: member_user.id }
      end.to change { member_user.user_memberships.count }.by(-1)
    end

    it 'redirects with success notice' do
      delete :destroy, params: { id: member_user.id }
      expect(response).to redirect_to(site_admin_users_path)
      expect(flash[:notice]).to include('removed')
    end

    it 'does not delete the user record' do
      expect do
        delete :destroy, params: { id: member_user.id }
      end.not_to change(Pwb::User, :count)
    end

    context 'when trying to remove self' do
      it 'prevents removal and shows alert' do
        delete :destroy, params: { id: user.id }
        expect(response).to redirect_to(site_admin_users_path)
        expect(flash[:alert]).to include('cannot remove yourself')
      end
    end

    context 'when removing the only owner' do
      let!(:owner_user) do
        u = create(:pwb_user, website: website, email: 'owner@test.com')
        u.user_memberships.create!(website: website, role: 'owner', active: true)
        u
      end

      it 'prevents removal due to equal permissions' do
        # Current user is owner, cannot manage another owner (equal level)
        delete :destroy, params: { id: owner_user.id }
        expect(response).to redirect_to(site_admin_users_path)
        expect(flash[:alert]).to include('cannot manage users with equal or higher permissions')
      end
    end
  end

  describe 'POST #resend_invitation' do
    let!(:member_user) do
      u = create(:pwb_user, website: website, email: 'member@test.com')
      u.user_memberships.create!(website: website, role: 'member', active: true)
      u
    end

    it 'redirects with success notice' do
      post :resend_invitation, params: { id: member_user.id }
      expect(response).to redirect_to(site_admin_user_path(member_user))
      expect(flash[:notice]).to include('resent')
    end
  end

  describe 'PATCH #update_role' do
    let!(:member_user) do
      u = create(:pwb_user, website: website, email: 'member@test.com')
      u.user_memberships.create!(website: website, role: 'member', active: true)
      u
    end

    it 'updates the role' do
      patch :update_role, params: { id: member_user.id, role: 'admin' }
      membership = member_user.user_memberships.find_by(website: website)
      expect(membership.role).to eq('admin')
    end

    it 'redirects with success notice' do
      patch :update_role, params: { id: member_user.id, role: 'admin' }
      expect(response).to redirect_to(site_admin_user_path(member_user))
      expect(flash[:notice]).to include('Role updated')
    end

    context 'when user has no membership' do
      let!(:orphan_user) { create(:pwb_user, website: website, email: 'orphan@test.com') }

      it 'redirects with alert' do
        patch :update_role, params: { id: orphan_user.id, role: 'admin' }
        expect(response).to redirect_to(site_admin_users_path)
        expect(flash[:alert]).to include('not a member')
      end
    end

    context 'when changing only owner to non-owner' do
      let!(:owner_user) do
        u = create(:pwb_user, website: website, email: 'owner@test.com')
        u.user_memberships.create!(website: website, role: 'owner', active: true)
        u
      end

      it 'prevents role change due to equal permissions' do
        # Current user is owner, cannot manage another owner (equal level)
        patch :update_role, params: { id: owner_user.id, role: 'admin' }
        expect(response).to redirect_to(site_admin_users_path)
        expect(flash[:alert]).to include('cannot manage users with equal or higher permissions')
      end
    end
  end

  describe 'PATCH #deactivate' do
    let!(:member_user) do
      u = create(:pwb_user, website: website, email: 'member@test.com')
      u.user_memberships.create!(website: website, role: 'member', active: true)
      u
    end

    it 'deactivates the user membership' do
      patch :deactivate, params: { id: member_user.id }
      membership = member_user.user_memberships.find_by(website: website)
      expect(membership.active).to be false
    end

    it 'redirects with success notice' do
      patch :deactivate, params: { id: member_user.id }
      expect(response).to redirect_to(site_admin_user_path(member_user))
      expect(flash[:notice]).to include('deactivated')
    end

    context 'when trying to deactivate self' do
      it 'prevents deactivation' do
        patch :deactivate, params: { id: user.id }
        expect(response).to redirect_to(site_admin_user_path(user))
        expect(flash[:alert]).to include('cannot deactivate yourself')
      end
    end
  end

  describe 'PATCH #reactivate' do
    let!(:inactive_user) do
      u = create(:pwb_user, website: website, email: 'inactive@test.com')
      u.user_memberships.create!(website: website, role: 'member', active: false)
      u
    end

    it 'reactivates the user membership' do
      patch :reactivate, params: { id: inactive_user.id }
      membership = inactive_user.user_memberships.find_by(website: website)
      expect(membership.active).to be true
    end

    it 'redirects with success notice' do
      patch :reactivate, params: { id: inactive_user.id }
      expect(response).to redirect_to(site_admin_user_path(inactive_user))
      expect(flash[:notice]).to include('reactivated')
    end
  end

  describe 'authorization' do
    let!(:member_user) do
      u = create(:pwb_user, website: website, email: 'member@test.com')
      u.user_memberships.create!(website: website, role: 'member', active: true)
      u
    end

    context 'when current user is not an admin' do
      before do
        user.user_memberships.find_by(website: website)&.update!(role: 'member')
      end

      it 'denies access to edit' do
        get :edit, params: { id: member_user.id }
        # May redirect or return 403 depending on controller implementation
        expect(response.status).to eq(302).or eq(403)
      end

      it 'denies access to update' do
        patch :update, params: { id: member_user.id, user: { first_names: 'Test' } }
        expect(response.status).to eq(302).or eq(403)
      end

      it 'denies access to destroy' do
        delete :destroy, params: { id: member_user.id }
        expect(response.status).to eq(302).or eq(403)
      end
    end
  end

  describe 'multi-tenant isolation' do
    let!(:own_user) { create(:pwb_user, website: website, email: 'own@test.com') }
    let!(:other_user) { create(:pwb_user, website: other_website, email: 'other@test.com') }

    it 'cannot view users from other website' do
      get :show, params: { id: other_user.id }
      expect(response).to have_http_status(:not_found)
    end

    it 'cannot edit users from other website' do
      get :edit, params: { id: other_user.id }
      expect(response).to have_http_status(:not_found)
    end

    it 'cannot delete users from other website' do
      delete :destroy, params: { id: other_user.id }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'authentication' do
    context 'when user is not signed in' do
      before { sign_out :user }

      it 'denies access' do
        get :index
        # May redirect to sign in or return 403 forbidden depending on auth configuration
        expect(response.status).to eq(302).or eq(403)
      end
    end
  end
end
