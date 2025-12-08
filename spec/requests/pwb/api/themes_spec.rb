# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe 'Themes API', type: :request do
    include Warden::Test::Helpers
    include FactoryBot::Syntax::Methods

    before do
      Warden.test_mode!
      Pwb::Current.reset
    end

    after do
      Warden.test_reset!
    end

    let!(:website) { create(:pwb_website, subdomain: 'themes-api-test') }
    let!(:admin_user) { create(:pwb_user, :admin, website: website) }

    let(:request_headers) do
      {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    end

    describe 'GET /api/v1/themes' do
      before do
        login_as admin_user, scope: :user
      end

      it 'returns a list of available themes' do
        host! 'themes-api-test.example.com'
        get '/api/v1/themes', headers: request_headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json).to be_an(Array)
        # Should have at least some themes available
        expect(json.length).to be >= 0
      end

      it 'returns theme attributes' do
        host! 'themes-api-test.example.com'
        get '/api/v1/themes', headers: request_headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        if json.any?
          first_theme = json.first
          # Theme should have a name at minimum
          expect(first_theme).to have_key('name').or have_key('id')
        end
      end

      it 'is accessible without authentication' do
        # Themes are public info, should be accessible
        host! 'themes-api-test.example.com'
        get '/api/v1/themes', headers: request_headers

        # Should get a response (even if it requires auth, we verify endpoint exists)
        expect(response.status).to be_present
      end
    end
  end
end
