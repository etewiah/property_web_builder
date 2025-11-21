require 'rails_helper'

module Pwb
  RSpec.describe "Api::V1::LiteProperties", type: :request do
    # include ::Devise::Test::IntegrationHelpers
    include Warden::Test::Helpers

    before do
      Warden.test_mode!
    end

    after do
      Warden.test_reset!
    end

    let(:admin_user) { Pwb::User.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password', admin: true) }
    let(:non_admin_user) { Pwb::User.create!(email: 'user@example.com', password: 'password', password_confirmation: 'password', admin: false) }

    describe "GET /api/v1/lite-properties" do
      context "when not logged in" do
        it "redirects to login page or returns 401" do
          get "/api/v1/lite-properties"
          expect(response).to have_http_status(302).or have_http_status(401)
        end
      end

      context "when logged in as admin" do
        before do
          login_as admin_user, scope: :user
        end

        it "returns success" do
          get "/api/v1/lite-properties"
          expect(response).to have_http_status(200)
        end
      end
    end
  end
end
