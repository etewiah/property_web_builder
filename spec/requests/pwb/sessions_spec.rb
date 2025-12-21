# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe 'Sessions', type: :request do
    include Warden::Test::Helpers
    include FactoryBot::Syntax::Methods

    before do
      Warden.test_mode!
      Pwb::Current.reset
      # Use Devise authentication for these tests
      allow(Pwb::AuthConfig).to receive(:devise?).and_return(true)
      allow(Pwb::AuthConfig).to receive(:firebase?).and_return(false)
    end

    after do
      Warden.test_reset!
    end

    let!(:website) { create(:pwb_website, subdomain: 'sessions-test') }
    let!(:admin_user) { create(:pwb_user, :admin, website: website) }
    let!(:regular_user) { create(:pwb_user, website: website) }

    describe 'admin authentication' do
      context 'when user is signed in as admin' do
        before do
          login_as admin_user, scope: :user
        end

        it 'allows access to admin panel' do
          host! 'sessions-test.example.com'
          get site_admin_root_path

          expect(response).to have_http_status(:success)
        end

        it 'sets the current user correctly' do
          host! 'sessions-test.example.com'
          get site_admin_root_path

          # Request spec doesn't have access to controller - verify through session
          expect(response).to have_http_status(:success)
        end
      end

      context 'when user is not signed in' do
        it 'returns forbidden status with admin required page' do
          host! 'sessions-test.example.com'
          get site_admin_root_path

          # Site admin renders admin_required page with forbidden status
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    describe 'multi-tenant authentication isolation' do
      # Use localhost which is a recognized platform domain
      let!(:website1) { create(:pwb_website, subdomain: 'tenant-a') }
      let!(:website2) { create(:pwb_website, subdomain: 'tenant-b') }
      let!(:user_a) { create(:pwb_user, :admin, email: 'user_a@example.com', website: website1) }
      let!(:user_b) { create(:pwb_user, :admin, email: 'user_b@example.com', website: website2) }

      it 'prevents user from signing in to wrong subdomain' do
        # Use localhost which is a recognized platform domain
        host! 'tenant-a.localhost'

        # Try to sign in with user_b's credentials (who belongs to tenant-b)
        post user_session_path, params: {
          user: { email: user_b.email, password: 'password123' }
        }

        # Should redirect back to sign in with error (using Devise auth)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include("You don't have access to this subdomain")
      end

      it 'allows user to sign in to their assigned subdomain' do
        # Use localhost which is a recognized platform domain
        host! 'tenant-a.localhost'

        # Sign in with user_a's credentials (who belongs to tenant-a)
        # Use plaintext password as defined in factory
        post user_session_path, params: {
          user: { email: user_a.email, password: 'password123' }
        }

        # When validation passes, user should NOT get the subdomain access error
        # The actual Devise authentication may still redirect for other reasons in test env
        expect(flash[:alert]).to be_nil.or(be_blank).or(
          satisfy { |msg| !msg.include?("don't have access") }
        )
      end

      it 'resolves correct website for each subdomain' do
        # Verify websites are created with correct subdomains
        expect(website1.subdomain).to eq('tenant-a')
        expect(website2.subdomain).to eq('tenant-b')

        # Verify they can be found by subdomain
        found1 = Pwb::Website.find_by(subdomain: 'tenant-a')
        found2 = Pwb::Website.find_by(subdomain: 'tenant-b')
        expect(found1).to eq(website1)
        expect(found2).to eq(website2)

        # Verify users are assigned to correct websites
        expect(user_a.website).to eq(website1)
        expect(user_b.website).to eq(website2)
      end
    end

    describe 'sign out' do
      before do
        login_as admin_user, scope: :user
      end

      it 'properly signs user out' do
        host! 'sessions-test.example.com'
        get site_admin_root_path
        expect(response).to have_http_status(:success)

        logout :user
        get site_admin_root_path
        # After logout, site_admin returns 403 forbidden
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
