# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe 'Export Web Contents', type: :request do
    include Warden::Test::Helpers
    include FactoryBot::Syntax::Methods

    before do
      Warden.test_mode!
      Pwb::Current.reset
    end

    after do
      Warden.test_reset!
    end

    let!(:website) { create(:pwb_website, subdomain: 'export-content-test') }
    let!(:admin_user) { create(:pwb_user, :admin, website: website) }

    describe 'GET /export/web_contents/all' do
      context 'with signed in admin user' do
        before do
          # Ensure admin user has membership for the website
          Pwb::UserMembership.find_or_create_by!(user: admin_user, website: website) do |m|
            m.role = 'admin'
            m.active = true
          end
          login_as admin_user, scope: :user
        end

        it 'is successful' do
          host! 'export-content-test.example.com'
          get '/export/web_contents/all'

          expect(response).to have_http_status(:success)
        end

        it 'requires authentication and responds' do
          host! 'export-content-test.example.com'
          get '/export/web_contents/all'

          # Should not redirect when authenticated
          expect(response).not_to have_http_status(:redirect)
        end
      end

      context 'without signed in user' do
        it 'redirects to sign_in page' do
          host! 'export-content-test.example.com'
          get '/export/web_contents/all'

          expect(response).to have_http_status(:redirect)
        end
      end
    end

    describe 'multi-tenant web contents export - subdomain resolution' do
      let!(:website1) { create(:pwb_website, subdomain: 'content-tenant1') }
      let!(:website2) { create(:pwb_website, subdomain: 'content-tenant2') }

      it 'requires authentication for export' do
        # Without auth
        host! 'content-tenant1.example.com'
        get '/export/web_contents/all'
        expect(response).to have_http_status(:redirect)
      end

      it 'allows access when authenticated' do
        # Ensure admin user has membership for website1
        Pwb::UserMembership.find_or_create_by!(user: admin_user, website: website1) do |m|
          m.role = 'admin'
          m.active = true
        end
        login_as admin_user, scope: :user
        host! 'content-tenant1.example.com'
        get '/export/web_contents/all'
        expect(response).to have_http_status(:success)
      end
    end
  end
end
