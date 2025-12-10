require "rails_helper"

RSpec.describe "AdminPanel subdomain login enforcement", type: :request do
  include Warden::Test::Helpers
  after { Warden.test_reset! }

  let!(:website1) { Pwb::Website.create!(subdomain: "site1", company_display_name: "Site 1") }
  let!(:website2) { Pwb::Website.create!(subdomain: "site2", company_display_name: "Site 2") }
  let!(:user1) { Pwb::User.create!(email: "admin1@site1.com", password: "password", admin: true, website: website1) }
  let!(:user2) { Pwb::User.create!(email: "admin2@site2.com", password: "password", admin: true, website: website2) }

  before do
    # Create user memberships for proper admin access
    Pwb::UserMembership.find_or_create_by!(user: user1, website: website1) do |m|
      m.role = 'admin'
      m.active = true
    end
    Pwb::UserMembership.find_or_create_by!(user: user2, website: website2) do |m|
      m.role = 'admin'
      m.active = true
    end
  end

  it "allows user to log in to their own subdomain" do
    host! "site1.localhost"
    login_as user1, scope: :user
    get "/site_admin"
    expect(response).to be_successful
  end

  it "blocks user from logging in to another subdomain" do
    host! "site2.localhost"
    login_as user1, scope: :user
    get "/site_admin"
    # User should be blocked from accessing other tenant's admin
    expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
  end
end
