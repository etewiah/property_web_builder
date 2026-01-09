# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pwb::SignupController Security', type: :request do
  before(:all) do
    Pwb::TenantSettings.delete_all
    Pwb::TenantSettings.create!(
      singleton_key: 'default',
      default_available_themes: %w[default]
    )
  end

  context 'when a default website already exists' do
    let!(:existing_website) do
      Pwb::Website.create!(
        subdomain: 'default',
        provisioning_state: 'live'
      )
    end

    it 'should redirect to root when accessing /signup from localhost' do
      # Simulate request from localhost (no subdomain)
      # If the site is already provisioned, we should probably not allow new signups
      # on the same "root" domain if it's meant to be a single-tenant instance masquerading as multi-tenant
      # OR if /signup is intended for multi-tenancy, it should be fine.
      # BUT, the user asked to "lock down setup" and check for "other such security issues".
      # If this is a single instance PWB, /signup allows creating NEW sites/tenants which might not be desired.

      # Let's see if we can access the page
      get '/signup', headers: { 'HTTP_HOST' => 'localhost:3000' }

      # If vulnerable/open, it returns 200. If secured, it should redirect or 404.
      # Expect redirect to root path as per the fix
      expect(response).to redirect_to(root_path)
    end
  end
end
