# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::UsersController', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'users-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@users-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/users (index)' do
    it 'renders the users list successfully' do
      get site_admin_users_path, headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    context 'with users' do
      let!(:member_user) { create(:pwb_user, :with_membership, website: website, email: 'member@test.com') }

      it 'displays users in the list' do
        get site_admin_users_path, headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('member@test.com')
      end

      it 'supports search by email' do
        get site_admin_users_path,
            params: { search: 'member' },
            headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('member@test.com')
      end
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-users') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }
      let!(:other_user) { create(:pwb_user, :with_membership, website: other_website, email: 'other@test.com') }

      it 'only shows users for current website' do
        get site_admin_users_path, headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('other@test.com')
      end
    end
  end

  describe 'GET /site_admin/users/:id (show)' do
    let!(:member_user) { create(:pwb_user, :with_membership, website: website, email: 'show@test.com') }

    it 'renders the user show page' do
      get site_admin_user_path(member_user),
          headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('show@test.com')
    end
  end

  describe 'GET /site_admin/users/new' do
    it 'renders the new user form' do
      get new_site_admin_user_path, headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /site_admin/users (create)' do
    context 'with new user email' do
      let(:new_user_params) do
        {
          user: {
            email: 'newuser@example.com',
            first_names: 'New',
            last_names: 'User',
            role: 'member'
          }
        }
      end

      it 'creates a new user and membership' do
        expect do
          post site_admin_users_path,
               params: new_user_params,
               headers: { 'HTTP_HOST' => 'users-test.test.localhost' }
        end.to change(Pwb::User, :count).by(1)
           .and change(Pwb::UserMembership, :count).by(1)
      end

      it 'redirects with success notice' do
        post site_admin_users_path,
             params: new_user_params,
             headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

        expect(response).to redirect_to(site_admin_users_path)
        expect(flash[:notice]).to include('Invitation sent')
      end
    end

    context 'with existing user email' do
      let!(:existing_user) { create(:pwb_user, email: 'existing@example.com') }

      it 'adds membership to existing user' do
        expect do
          post site_admin_users_path,
               params: { user: { email: 'existing@example.com', role: 'member' } },
               headers: { 'HTTP_HOST' => 'users-test.test.localhost' }
        end.to change(Pwb::UserMembership, :count).by(1)
           .and change(Pwb::User, :count).by(0)
      end

      it 'redirects with success notice' do
        post site_admin_users_path,
             params: { user: { email: 'existing@example.com', role: 'member' } },
             headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

        expect(response).to redirect_to(site_admin_users_path)
        expect(flash[:notice]).to include('has been added')
      end
    end

    context 'with user already member of website' do
      let!(:existing_member) { create(:pwb_user, :with_membership, website: website, email: 'already@example.com') }

      it 'returns error' do
        post site_admin_users_path,
             params: { user: { email: 'already@example.com' } },
             headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to include('already a member')
      end
    end
  end

  describe 'GET /site_admin/users/:id/edit' do
    let!(:member_user) { create(:pwb_user, :with_membership, website: website, email: 'edit@test.com') }

    it 'renders the edit form' do
      get edit_site_admin_user_path(member_user),
          headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /site_admin/users/:id (update)' do
    let!(:member_user) { create(:pwb_user, :with_membership, website: website, email: 'update@test.com', first_names: 'Old') }

    it 'updates user details' do
      patch site_admin_user_path(member_user),
            params: { user: { first_names: 'New', last_names: 'Name' } },
            headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      member_user.reload
      expect(member_user.first_names).to eq('New')
      expect(member_user.last_names).to eq('Name')
    end

    it 'redirects to show page' do
      patch site_admin_user_path(member_user),
            params: { user: { first_names: 'Updated' } },
            headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      expect(response).to redirect_to(site_admin_user_path(member_user))
      expect(flash[:notice]).to include('updated successfully')
    end
  end

  describe 'DELETE /site_admin/users/:id (destroy)' do
    let!(:member_user) { create(:pwb_user, :with_membership, website: website, email: 'delete@test.com') }

    it 'removes membership (not the user)' do
      expect do
        delete site_admin_user_path(member_user),
               headers: { 'HTTP_HOST' => 'users-test.test.localhost' }
      end.to change(Pwb::UserMembership, :count).by(-1)
         .and change(Pwb::User, :count).by(0)
    end

    it 'redirects with success notice' do
      delete site_admin_user_path(member_user),
             headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      expect(response).to redirect_to(site_admin_users_path)
      expect(flash[:notice]).to include('removed from the team')
    end

    context 'when trying to remove self' do
      it 'returns error' do
        delete site_admin_user_path(admin_user),
               headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

        expect(response).to redirect_to(site_admin_users_path)
        expect(flash[:alert]).to include('cannot remove yourself')
      end
    end

    context 'when trying to remove only owner' do
      let!(:owner_user) do
        user = create(:pwb_user, website: website, email: 'owner@test.com')
        create(:pwb_user_membership, :owner, user: user, website: website)
        user
      end

      it 'returns error due to permission restrictions' do
        # Make admin_user not an owner
        admin_membership = admin_user.user_memberships.find_by(website: website)
        admin_membership.update!(role: 'admin')

        delete site_admin_user_path(owner_user),
               headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

        # Admin cannot manage users with higher permissions (owner)
        expect(response).to redirect_to(site_admin_users_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'POST /site_admin/users/:id/resend_invitation' do
    let!(:member_user) { create(:pwb_user, :with_membership, website: website, email: 'resend@test.com') }

    it 'redirects with success notice' do
      post resend_invitation_site_admin_user_path(member_user),
           headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      expect(response).to redirect_to(site_admin_user_path(member_user))
      expect(flash[:notice]).to include('Invitation resent')
    end
  end

  describe 'PATCH /site_admin/users/:id/update_role' do
    let!(:member_user) { create(:pwb_user, :with_membership, website: website, email: 'role@test.com') }

    it 'updates user role' do
      patch update_role_site_admin_user_path(member_user),
            params: { role: 'admin' },
            headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      membership = member_user.user_memberships.find_by(website: website)
      expect(membership.role).to eq('admin')
    end

    it 'redirects with success notice' do
      patch update_role_site_admin_user_path(member_user),
            params: { role: 'admin' },
            headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      expect(response).to redirect_to(site_admin_user_path(member_user))
      expect(flash[:notice]).to include('Role updated')
    end
  end

  describe 'PATCH /site_admin/users/:id/deactivate' do
    let!(:member_user) { create(:pwb_user, :with_membership, website: website, email: 'deactivate@test.com') }

    it 'deactivates user membership' do
      patch deactivate_site_admin_user_path(member_user),
            headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      membership = member_user.user_memberships.find_by(website: website)
      expect(membership.active).to be false
    end

    it 'redirects with success notice' do
      patch deactivate_site_admin_user_path(member_user),
            headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      expect(response).to redirect_to(site_admin_user_path(member_user))
      expect(flash[:notice]).to include('deactivated')
    end

    context 'when trying to deactivate self' do
      it 'returns error' do
        patch deactivate_site_admin_user_path(admin_user),
              headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

        expect(response).to redirect_to(site_admin_user_path(admin_user))
        expect(flash[:alert]).to include('cannot deactivate yourself')
      end
    end
  end

  describe 'PATCH /site_admin/users/:id/reactivate' do
    let!(:inactive_user) do
      user = create(:pwb_user, website: website, email: 'reactivate@test.com')
      create(:pwb_user_membership, :inactive, user: user, website: website)
      user
    end

    it 'reactivates user membership' do
      patch reactivate_site_admin_user_path(inactive_user),
            headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      membership = inactive_user.user_memberships.find_by(website: website)
      expect(membership.active).to be true
    end

    it 'redirects with success notice' do
      patch reactivate_site_admin_user_path(inactive_user),
            headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      expect(response).to redirect_to(site_admin_user_path(inactive_user))
      expect(flash[:notice]).to include('reactivated')
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users on index' do
      get site_admin_users_path,
          headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it 'blocks unauthenticated users on create' do
      post site_admin_users_path,
           params: { user: { email: 'test@test.com' } },
           headers: { 'HTTP_HOST' => 'users-test.test.localhost' }

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
