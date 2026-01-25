# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantAdmin::ShardsController, type: :controller do
  # Use a dedicated shard for the admin user's website to avoid
  # interference with user counting tests on the 'default' shard
  let(:website) { create(:pwb_website, subdomain: 'test-site', shard_name: 'admin_shard') }
  let(:admin_user) { create(:pwb_user, email: 'admin@example.com', website: website) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
    sign_in admin_user, scope: :user

    # Mock shard registry for tests
    allow(Pwb::ShardRegistry).to receive(:logical_shards).and_return([:default, :shard_a])
    allow(Pwb::ShardRegistry).to receive(:configured?).and_return(true)
    allow(Pwb::ShardRegistry).to receive(:describe_shard).and_return({
      configured: true,
      database: 'test_db',
      host: 'localhost'
    })
    allow(Pwb::ShardHealthCheck).to receive(:check).and_return(
      OpenStruct.new(
        connection_status: true,
        avg_query_ms: 1.5,
        database_size: '100 MB'
      )
    )
  end

  describe 'GET #index' do
    it 'returns a successful response' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns @shards' do
      get :index
      expect(assigns(:shards)).to be_present
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { id: 'default' }
      expect(response).to have_http_status(:success)
    end

    it 'assigns @shard_name' do
      get :show, params: { id: 'default' }
      expect(assigns(:shard_name)).to eq('default')
    end

    context 'with unconfigured shard' do
      before do
        allow(Pwb::ShardRegistry).to receive(:configured?).with(:unconfigured).and_return(false)
      end

      it 'redirects to shards index' do
        get :show, params: { id: 'unconfigured' }
        expect(response).to redirect_to(tenant_admin_shards_path)
      end

      it 'sets an alert message' do
        get :show, params: { id: 'unconfigured' }
        expect(flash[:alert]).to include('not configured')
      end
    end
  end

  describe 'GET #websites' do
    let!(:shard_website1) { create(:pwb_website, subdomain: 'shard-site-1', shard_name: 'default') }
    let!(:shard_website2) { create(:pwb_website, subdomain: 'shard-site-2', shard_name: 'default') }
    let!(:other_shard_website) { create(:pwb_website, subdomain: 'other-shard', shard_name: 'shard_a') }

    it 'returns a successful response' do
      get :websites, params: { id: 'default' }
      expect(response).to have_http_status(:success)
    end

    it 'assigns @websites for the specified shard' do
      get :websites, params: { id: 'default' }
      expect(assigns(:websites)).to include(shard_website1, shard_website2)
      expect(assigns(:websites)).not_to include(other_shard_website)
    end

    describe 'user counting across shard websites' do
      # The shards/websites view shows totals for all websites in the shard.
      # User counting must include:
      # 1. Users with direct website_id association
      # 2. Users with user_memberships to any website in the shard
      # Without double-counting users who appear in both.

      context 'with no users in shard' do
        it 'sets @total_users to 0' do
          get :websites, params: { id: 'default' }
          expect(assigns(:total_users)).to eq(0)
        end
      end

      context 'with users via direct website_id' do
        let!(:user1) { create(:pwb_user, website: shard_website1) }
        let!(:user2) { create(:pwb_user, website: shard_website2) }

        it 'counts users across all websites in the shard' do
          get :websites, params: { id: 'default' }
          expect(assigns(:total_users)).to eq(2)
        end

        it 'does not count users from other shards' do
          create(:pwb_user, website: other_shard_website)
          get :websites, params: { id: 'default' }
          expect(assigns(:total_users)).to eq(2)
        end
      end

      context 'with users via user_memberships' do
        let(:external_website) { create(:pwb_website, subdomain: 'external', shard_name: 'shard_a') }
        let!(:membership_user) { create(:pwb_user, website: external_website) }
        let!(:membership) { create(:pwb_user_membership, user: membership_user, website: shard_website1) }

        it 'counts users with memberships to shard websites' do
          get :websites, params: { id: 'default' }
          expect(assigns(:total_users)).to eq(1)
        end
      end

      context 'with mixed direct and membership users' do
        let!(:direct_user) { create(:pwb_user, website: shard_website1) }
        let(:external_website) { create(:pwb_website, subdomain: 'external', shard_name: 'shard_a') }
        let!(:membership_user) { create(:pwb_user, website: external_website) }
        let!(:membership) { create(:pwb_user_membership, user: membership_user, website: shard_website2) }

        it 'counts both types of users' do
          get :websites, params: { id: 'default' }
          expect(assigns(:total_users)).to eq(2)
        end
      end

      context 'with user having both direct and membership to same shard' do
        # Edge case: User has website_id pointing to a shard website AND
        # also has memberships to other websites in the same shard.
        # Should count as 1 user, not multiple.
        let!(:dual_user) { create(:pwb_user, website: shard_website1) }
        let!(:membership) { create(:pwb_user_membership, user: dual_user, website: shard_website2) }

        it 'does not double-count users' do
          get :websites, params: { id: 'default' }
          expect(assigns(:total_users)).to eq(1)
        end
      end
    end

    describe 'property counting' do
      context 'with no properties' do
        it 'sets @total_properties to 0' do
          get :websites, params: { id: 'default' }
          expect(assigns(:total_properties)).to eq(0)
        end
      end

      context 'with properties' do
        before do
          create_list(:pwb_realty_asset, 3, website: shard_website1)
          create_list(:pwb_realty_asset, 2, website: shard_website2)
        end

        it 'counts properties across all websites in the shard' do
          get :websites, params: { id: 'default' }
          expect(assigns(:total_properties)).to eq(5)
        end
      end
    end
  end

  describe 'GET #health' do
    it 'returns a successful response' do
      get :health, params: { id: 'default' }
      expect(response).to have_http_status(:success)
    end

    it 'assigns @health' do
      get :health, params: { id: 'default' }
      expect(assigns(:health)).to be_present
    end

    context 'as JSON' do
      it 'returns health data' do
        get :health, params: { id: 'default', format: :json }
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('application/json')
      end
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

      it 'denies access to websites' do
        get :websites, params: { id: 'default' }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe '#count_users_for_websites (private method)' do
    # Testing the private method indirectly through controller behavior

    let!(:website_a) { create(:pwb_website, subdomain: 'site-a', shard_name: 'default') }
    let!(:website_b) { create(:pwb_website, subdomain: 'site-b', shard_name: 'default') }

    it 'returns 0 for empty website_ids array' do
      # Use shard with no websites
      allow(Pwb::ShardRegistry).to receive(:configured?).with(:empty).and_return(true)
      create(:pwb_website, subdomain: 'empty-test', shard_name: 'empty')
      Pwb::Website.unscoped.where(shard_name: 'empty').destroy_all

      get :websites, params: { id: 'empty' }
      expect(assigns(:total_users)).to eq(0)
    end

    it 'correctly handles large numbers of websites' do
      # Create additional websites
      5.times do |i|
        w = create(:pwb_website, subdomain: "bulk-site-#{i}", shard_name: 'default')
        create(:pwb_user, website: w)
      end

      get :websites, params: { id: 'default' }
      expect(assigns(:total_users)).to eq(5)
    end
  end
end
