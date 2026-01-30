# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::Integrations', type: :request do
  let(:website) { create(:website) }

  before do
    # Set up the subdomain tenant
    allow_any_instance_of(SiteAdminController).to receive(:current_website).and_return(website)
    allow_any_instance_of(SiteAdminController).to receive(:bypass_admin_auth?).and_return(true)
  end

  describe 'GET /site_admin/integrations' do
    it 'returns success' do
      get site_admin_integrations_path
      expect(response).to have_http_status(:success)
    end

    it 'displays available AI providers' do
      get site_admin_integrations_path
      expect(response.body).to include('Anthropic')
      expect(response.body).to include('OpenAI')
    end

    context 'with configured integration' do
      let!(:integration) { create(:pwb_website_integration, :anthropic, website: website) }

      it 'shows the integration status' do
        get site_admin_integrations_path
        expect(response.body).to include('Connected')
      end
    end
  end

  describe 'GET /site_admin/integrations/new' do
    it 'returns success for valid provider' do
      get new_site_admin_integration_path(category: 'ai', provider: 'anthropic')
      expect(response).to have_http_status(:success)
    end

    it 'shows the provider configuration form' do
      get new_site_admin_integration_path(category: 'ai', provider: 'anthropic')
      expect(response.body).to include('API Key')
      expect(response.body).to include('Default Model')
    end

    it 'redirects for invalid provider' do
      get new_site_admin_integration_path(category: 'ai', provider: 'invalid')
      expect(response).to redirect_to(site_admin_integrations_path)
    end
  end

  describe 'POST /site_admin/integrations' do
    let(:valid_params) do
      {
        integration: {
          category: 'ai',
          provider: 'anthropic'
        },
        credentials: {
          api_key: 'sk-test-key-12345'
        },
        settings: {
          default_model: 'claude-sonnet-4-20250514'
        }
      }
    end

    it 'creates a new integration' do
      expect {
        post site_admin_integrations_path, params: valid_params
      }.to change(Pwb::WebsiteIntegration, :count).by(1)
    end

    it 'redirects to index on success' do
      post site_admin_integrations_path, params: valid_params
      expect(response).to redirect_to(site_admin_integrations_path)
    end

    it 'stores encrypted credentials' do
      post site_admin_integrations_path, params: valid_params
      integration = Pwb::WebsiteIntegration.last
      expect(integration.credential(:api_key)).to eq('sk-test-key-12345')
    end

    it 'stores settings' do
      post site_admin_integrations_path, params: valid_params
      integration = Pwb::WebsiteIntegration.last
      expect(integration.setting(:default_model)).to eq('claude-sonnet-4-20250514')
    end
  end

  describe 'GET /site_admin/integrations/:id/edit' do
    let!(:integration) { create(:pwb_website_integration, :anthropic, website: website) }

    it 'returns success' do
      get edit_site_admin_integration_path(integration)
      expect(response).to have_http_status(:success)
    end

    it 'shows masked credentials' do
      get edit_site_admin_integration_path(integration)
      # Should show masked version, not actual key
      expect(response.body).to include('Configure Anthropic')
    end
  end

  describe 'PATCH /site_admin/integrations/:id' do
    let!(:integration) { create(:pwb_website_integration, :anthropic, website: website) }

    it 'updates settings' do
      patch site_admin_integration_path(integration), params: {
        integration: { category: 'ai', provider: 'anthropic' },
        settings: { default_model: 'claude-opus-4-20250514' }
      }

      integration.reload
      expect(integration.setting(:default_model)).to eq('claude-opus-4-20250514')
    end

    it 'does not update credentials with masked placeholder' do
      original_key = integration.credential(:api_key)

      patch site_admin_integration_path(integration), params: {
        integration: { category: 'ai', provider: 'anthropic' },
        credentials: { api_key: '••••••••key' }
      }

      integration.reload
      expect(integration.credential(:api_key)).to eq(original_key)
    end

    it 'updates credentials when new value provided' do
      patch site_admin_integration_path(integration), params: {
        integration: { category: 'ai', provider: 'anthropic' },
        credentials: { api_key: 'sk-new-key-67890' }
      }

      integration.reload
      expect(integration.credential(:api_key)).to eq('sk-new-key-67890')
    end

    it 'redirects to index on success' do
      patch site_admin_integration_path(integration), params: {
        integration: { category: 'ai', provider: 'anthropic' }
      }
      expect(response).to redirect_to(site_admin_integrations_path)
    end
  end

  describe 'DELETE /site_admin/integrations/:id' do
    let!(:integration) { create(:pwb_website_integration, :anthropic, website: website) }

    it 'deletes the integration' do
      expect {
        delete site_admin_integration_path(integration)
      }.to change(Pwb::WebsiteIntegration, :count).by(-1)
    end

    it 'redirects to index' do
      delete site_admin_integration_path(integration)
      expect(response).to redirect_to(site_admin_integrations_path)
    end
  end

  describe 'POST /site_admin/integrations/:id/test_connection' do
    let!(:integration) { create(:pwb_website_integration, :anthropic, website: website) }

    context 'when connection succeeds' do
      before do
        allow_any_instance_of(Pwb::WebsiteIntegration).to receive(:test_connection).and_return(true)
      end

      it 'redirects with success message' do
        post test_connection_site_admin_integration_path(integration)
        expect(response).to redirect_to(site_admin_integrations_path)
        expect(flash[:notice]).to include('connection successful')
      end
    end

    context 'when connection fails' do
      before do
        allow_any_instance_of(Pwb::WebsiteIntegration).to receive(:test_connection).and_return(false)
        allow_any_instance_of(Pwb::WebsiteIntegration).to receive(:last_error_message).and_return('Invalid API key')
      end

      it 'redirects with error message' do
        post test_connection_site_admin_integration_path(integration)
        expect(response).to redirect_to(site_admin_integrations_path)
        expect(flash[:alert]).to include('Connection failed')
      end
    end
  end

  describe 'POST /site_admin/integrations/:id/toggle' do
    let!(:integration) { create(:pwb_website_integration, :anthropic, website: website, enabled: true) }

    it 'toggles enabled status' do
      post toggle_site_admin_integration_path(integration)
      integration.reload
      expect(integration.enabled?).to be false
    end

    it 'toggles back to enabled' do
      integration.update!(enabled: false)
      post toggle_site_admin_integration_path(integration)
      integration.reload
      expect(integration.enabled?).to be true
    end
  end

  describe 'multi-tenant isolation' do
    let!(:other_website) { create(:website) }
    let!(:other_integration) { create(:pwb_website_integration, :anthropic, website: other_website) }

    it 'cannot access integrations from other websites' do
      get edit_site_admin_integration_path(other_integration)
      # Should return 404 due to rescue_from ActiveRecord::RecordNotFound
      expect(response).to have_http_status(:not_found)
    end

    it 'cannot delete integrations from other websites' do
      expect {
        delete site_admin_integration_path(other_integration)
      }.not_to change(Pwb::WebsiteIntegration, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
