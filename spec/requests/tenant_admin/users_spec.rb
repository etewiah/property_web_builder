# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TenantAdmin::Users', type: :request do
  let(:website) { create(:pwb_website, subdomain: 'users-test-site') }

  before do
    ENV['BYPASS_ADMIN_AUTH'] = 'true'
  end

  after do
    ENV['BYPASS_ADMIN_AUTH'] = nil
  end

  describe 'GET /tenant_admin/users' do
    let!(:user_a) { create(:pwb_user, email: 'alice@example.com', website: website) }
    let!(:user_b) { create(:pwb_user, email: 'bob@example.com', admin: true, website: website) }

    it 'returns a list of all users' do
      get '/tenant_admin/users'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('alice@example.com')
      expect(response.body).to include('bob@example.com')
    end

    it 'supports search by email' do
      get '/tenant_admin/users', params: { search: 'alice' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('alice@example.com')
    end

    it 'filters by admin status' do
      get '/tenant_admin/users', params: { admin: 'true' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('bob@example.com')
    end
  end

  describe 'GET /tenant_admin/users/:id' do
    let!(:target_user) { create(:pwb_user, email: 'target@example.com', website: website) }

    it 'shows user details' do
      get "/tenant_admin/users/#{target_user.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('target@example.com')
    end
  end

  describe 'GET /tenant_admin/users/new' do
    it 'renders the new user form' do
      get '/tenant_admin/users/new'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /tenant_admin/users' do
    let(:valid_params) do
      {
        pwb_user: {
          email: 'newuser@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          pwb_website_id: website.id
        }
      }
    end

    it 'creates a new user with valid params' do
      expect {
        post '/tenant_admin/users', params: valid_params
      }.to change(Pwb::User, :count).by(1)

      expect(response).to have_http_status(:redirect)
    end

    it 'returns error for missing email' do
      post '/tenant_admin/users', params: {
        pwb_user: {
          email: '',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns error for password mismatch' do
      post '/tenant_admin/users', params: {
        pwb_user: {
          email: 'mismatch@example.com',
          password: 'password123',
          password_confirmation: 'differentpassword',
          pwb_website_id: website.id
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /tenant_admin/users/:id/edit' do
    let!(:target_user) { create(:pwb_user, email: 'edit-user@example.com', website: website) }

    it 'renders the edit form' do
      get "/tenant_admin/users/#{target_user.id}/edit"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('edit-user@example.com')
    end
  end

  describe 'PATCH /tenant_admin/users/:id' do
    let!(:target_user) { create(:pwb_user, email: 'update-user@example.com', website: website) }

    it 'updates user email' do
      patch "/tenant_admin/users/#{target_user.id}", params: {
        pwb_user: { email: 'updated-email@example.com' }
      }
      expect(response).to have_http_status(:redirect)

      target_user.reload
      expect(target_user.email).to eq('updated-email@example.com')
    end

    it 'updates admin status' do
      expect(target_user.admin).to be_falsey

      patch "/tenant_admin/users/#{target_user.id}", params: {
        pwb_user: { admin: true }
      }
      expect(response).to have_http_status(:redirect)

      target_user.reload
      expect(target_user.admin).to be_truthy
    end
  end

  describe 'DELETE /tenant_admin/users/:id' do
    let!(:target_user) { create(:pwb_user, email: 'delete-user@example.com', website: website) }

    it 'deletes the user' do
      expect {
        delete "/tenant_admin/users/#{target_user.id}"
      }.to change(Pwb::User, :count).by(-1)

      expect(response).to have_http_status(:redirect)
    end
  end
end
