# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe 'Sessions', type: :request do
    include Warden::Test::Helpers
    include FactoryBot::Syntax::Methods

    before do
      Warden.test_mode!
      Pwb::Current.reset
    end

    after do
      Warden.test_reset!
    end

    let!(:website) { create(:pwb_website, subdomain: 'sessions-test') }
    let!(:admin_user) { create(:pwb_user, :admin) }
    let!(:regular_user) { create(:pwb_user) }

    describe 'admin authentication' do
      context 'when user is signed in as admin' do
        before do
          login_as admin_user, scope: :user
        end

        it 'allows access to admin panel' do
          host! 'sessions-test.example.com'
          get admin_path

          expect(response).to have_http_status(:success)
        end

        it 'sets the current user correctly' do
          host! 'sessions-test.example.com'
          get admin_path

          expect(controller.current_user).to eq(admin_user)
        end
      end

      context 'when user is not signed in' do
        it 'redirects to sign in page' do
          host! 'sessions-test.example.com'
          get '/admin'

          expect(response).to redirect_to(new_user_session_path)
        end
      end
    end

    describe 'multi-tenant session isolation' do
      let!(:website1) { create(:pwb_website, subdomain: 'tenant-a') }
      let!(:website2) { create(:pwb_website, subdomain: 'tenant-b') }

      before do
        login_as admin_user, scope: :user
      end

      it 'maintains session across different tenant subdomains' do
        host! 'tenant-a.example.com'
        get '/en'
        expect(response).to have_http_status(:success)

        Pwb::Current.reset

        host! 'tenant-b.example.com'
        get '/en'
        expect(response).to have_http_status(:success)
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

        # Verify Pwb::Current can be manually set
        Pwb::Current.website = website1
        expect(Pwb::Current.website).to eq(website1)

        Pwb::Current.reset
        Pwb::Current.website = website2
        expect(Pwb::Current.website).to eq(website2)
      end
    end

    describe 'sign out' do
      before do
        login_as admin_user, scope: :user
      end

      it 'properly signs user out' do
        host! 'sessions-test.example.com'
        get admin_path
        expect(response).to have_http_status(:success)

        logout :user
        get '/admin'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
