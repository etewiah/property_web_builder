# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pwb::SetupController Security', type: :request do
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

    it 'should redirect to root when accessing /setup from localhost' do
      # Simulate request from localhost (no subdomain)
      get '/setup', headers: { 'HTTP_HOST' => 'localhost:3000' }

      # It currently succeeds (200), but we expect it to redirect (302)
      expect(response).to redirect_to(root_path)
    end
  end
end
