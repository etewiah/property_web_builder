# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TenantAdmin::Websites Rendering Mode', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'admin-site', rendering_mode: 'rails') }
  let!(:client_theme) { create(:pwb_client_theme, :amsterdam) }
  
  before do
    ENV['BYPASS_ADMIN_AUTH'] = 'true'
    # Set up tenant settings if needed
    Pwb::TenantSettings.find_or_create_by!(singleton_key: 'default') do |ts|
      ts.default_available_themes = %w[default brisbane]
    end
  end

  after do
    ENV['BYPASS_ADMIN_AUTH'] = nil
  end

  describe 'PATCH /tenant_admin/websites/:id' do
    context 'when mode is not locked' do
      it 'updates rendering_mode and client_theme_name' do
        patch "/tenant_admin/websites/#{website.id}", params: {
          website: {
            rendering_mode: 'client',
            client_theme_name: 'amsterdam'
          }
        }
        
        expect(response).to have_http_status(:redirect)
        website.reload
        expect(website.rendering_mode).to eq('client')
        expect(website.client_theme_name).to eq('amsterdam')
      end

      it 'returns error for invalid rendering_mode' do
        patch "/tenant_admin/websites/#{website.id}", params: {
          website: { rendering_mode: 'invalid' }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        website.reload
        expect(website.rendering_mode).to eq('rails')
      end
    end

    context 'when mode is locked' do
      let!(:locked_website) { create(:pwb_website, :provisioned_with_content, rendering_mode: 'rails') }

      it 'fails to update rendering_mode' do
        patch "/tenant_admin/websites/#{locked_website.id}", params: {
          website: { rendering_mode: 'client' }
        }
        
        # In Rails, if a validation fails, update returns false.
        # The controller should render edit with errors.
        expect(response).to have_http_status(:unprocessable_entity)
        locked_website.reload
        expect(locked_website.rendering_mode).to eq('rails')
      end

      it 'allows updating other fields' do
        patch "/tenant_admin/websites/#{locked_website.id}", params: {
          website: { company_display_name: 'New Name' }
        }

        expect(response).to have_http_status(:redirect)
        locked_website.reload
        expect(locked_website.company_display_name).to eq('New Name')
        expect(locked_website.rendering_mode).to eq('rails')
      end
    end
  end

  describe 'PATCH /tenant_admin/websites/:id/update_rendering' do
    let!(:client_website) do
      create(:pwb_website,
        subdomain: 'client-site',
        rendering_mode: 'client',
        client_theme_name: 'amsterdam',
        client_theme_config: {}
      )
    end

    context 'astro_client_url' do
      it 'sets astro_client_url in client_theme_config' do
        patch "/tenant_admin/websites/#{client_website.id}/update_rendering", params: {
          website: {
            rendering_mode: 'client',
            client_theme_name: 'amsterdam',
            astro_client_url: 'https://custom-astro.example.com'
          }
        }

        expect(response).to have_http_status(:ok)
        client_website.reload
        expect(client_website.client_theme_config['astro_client_url']).to eq('https://custom-astro.example.com')
      end

      it 'removes astro_client_url when set to blank' do
        client_website.update!(client_theme_config: { 'astro_client_url' => 'https://old-url.com' })

        patch "/tenant_admin/websites/#{client_website.id}/update_rendering", params: {
          website: {
            rendering_mode: 'client',
            client_theme_name: 'amsterdam',
            astro_client_url: ''
          }
        }

        expect(response).to have_http_status(:ok)
        client_website.reload
        expect(client_website.client_theme_config['astro_client_url']).to be_nil
      end

      it 'preserves other client_theme_config values when updating astro_client_url' do
        client_website.update!(client_theme_config: { 'primary_color' => '#FF0000' })

        patch "/tenant_admin/websites/#{client_website.id}/update_rendering", params: {
          website: {
            rendering_mode: 'client',
            client_theme_name: 'amsterdam',
            astro_client_url: 'https://new-astro.example.com'
          }
        }

        expect(response).to have_http_status(:ok)
        client_website.reload
        expect(client_website.client_theme_config['astro_client_url']).to eq('https://new-astro.example.com')
        expect(client_website.client_theme_config['primary_color']).to eq('#FF0000')
      end
    end
  end
end
