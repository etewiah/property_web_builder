# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe ClientProxyController, type: :controller do
    # Set up tenant settings
    before(:all) do
      Pwb::TenantSettings.find_or_create_by!(singleton_key: 'default') do |ts|
        ts.default_available_themes = %w[default brisbane]
      end
    end

    let!(:client_theme) { create(:pwb_client_theme, :amsterdam) }

    describe '#public_proxy' do
      context 'with rails-rendered website' do
        let!(:website) { create(:pwb_website, subdomain: 'rails-site', rendering_mode: 'rails') }

        before do
          allow(controller).to receive(:current_website).and_return(website)
          controller.instance_variable_set(:@current_website, website)
        end

        it 'raises routing error for non-client websites' do
          expect { get :public_proxy, params: { path: 'test' } }
            .to raise_error(ActionController::RoutingError)
        end
      end

      context 'with client-rendered website' do
        let!(:website) do
          create(:pwb_website, subdomain: 'client-site', rendering_mode: 'client', client_theme_name: 'amsterdam')
        end

        before do
          allow(controller).to receive(:current_website).and_return(website)
          controller.instance_variable_set(:@current_website, website)
        end

        it 'proxies request when Astro client is available', :vcr do
          stub_request(:get, /localhost:4321/)
            .to_return(status: 200, body: '<html>Astro Content</html>', headers: { 'Content-Type' => 'text/html' })

          get :public_proxy, params: { path: 'test' }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include('Astro Content')
        end

        it 'renders error when Astro client is unavailable' do
          stub_request(:get, /localhost:4321/)
            .to_raise(HTTP::ConnectionError)

          get :public_proxy, params: { path: 'test' }

          expect(response).to have_http_status(:service_unavailable)
        end
      end
    end

    describe '#admin_proxy' do
      let!(:website) do
        create(:pwb_website, subdomain: 'client-site', rendering_mode: 'client', client_theme_name: 'amsterdam')
      end
      let(:user) { create(:pwb_user, website: website) }

      before do
        @request.env['devise.mapping'] = ::Devise.mappings[:user]
        allow(controller).to receive(:current_website).and_return(website)
        controller.instance_variable_set(:@current_website, website)
      end

      context 'when not signed in' do
        it 'redirects to login' do
          get :admin_proxy, params: { path: 'dashboard' }

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context 'when signed in' do
        before { sign_in user }

        it 'proxies request with auth headers' do
          stub_request(:get, /localhost:4321/)
            .to_return(status: 200, body: '<html>Admin Content</html>', headers: { 'Content-Type' => 'text/html' })

          get :admin_proxy, params: { path: 'dashboard' }

          expect(response).to have_http_status(:ok)

          # Verify auth headers were sent (via WebMock)
          expect(a_request(:get, /localhost:4321/).with do |req|
            req.headers['X-Auth-Token'].present?
          end).to have_been_made
        end
      end
    end

    describe '#astro_client_url' do
      context 'with tenant-specific URL in client_theme_config' do
        let!(:website) do
          create(:pwb_website,
            subdomain: 'custom-astro',
            rendering_mode: 'client',
            client_theme_name: 'amsterdam',
            client_theme_config: { 'astro_client_url' => 'https://tenant-astro.example.com' }
          )
        end

        before do
          allow(controller).to receive(:current_website).and_return(website)
          controller.instance_variable_set(:@current_website, website)
        end

        it 'uses the tenant-specific Astro URL' do
          stub_request(:get, %r{tenant-astro\.example\.com})
            .to_return(status: 200, body: '<html>Tenant Astro</html>', headers: { 'Content-Type' => 'text/html' })

          get :public_proxy, params: { path: 'test' }

          expect(response).to have_http_status(:ok)
          expect(a_request(:get, %r{tenant-astro\.example\.com})).to have_been_made
        end

        it 'returns the tenant URL from astro_client_url method' do
          expect(controller.send(:astro_client_url)).to eq('https://tenant-astro.example.com')
        end
      end

      context 'with empty astro_client_url in client_theme_config' do
        let!(:website) do
          create(:pwb_website,
            subdomain: 'empty-url',
            rendering_mode: 'client',
            client_theme_name: 'amsterdam',
            client_theme_config: { 'astro_client_url' => '' }
          )
        end

        before do
          allow(controller).to receive(:current_website).and_return(website)
          controller.instance_variable_set(:@current_website, website)
        end

        it 'falls back to default when URL is blank' do
          stub_request(:get, /localhost:4321/)
            .to_return(status: 200, body: '<html>Default Astro</html>', headers: { 'Content-Type' => 'text/html' })

          get :public_proxy, params: { path: 'test' }

          expect(response).to have_http_status(:ok)
          expect(a_request(:get, /localhost:4321/)).to have_been_made
        end
      end

      context 'without tenant-specific URL (empty config)' do
        let!(:website) do
          create(:pwb_website,
            subdomain: 'default-astro',
            rendering_mode: 'client',
            client_theme_name: 'amsterdam',
            client_theme_config: {}
          )
        end

        before do
          allow(controller).to receive(:current_website).and_return(website)
          controller.instance_variable_set(:@current_website, website)
        end

        it 'falls back to environment variable or default' do
          stub_request(:get, /localhost:4321/)
            .to_return(status: 200, body: '<html>Default Astro</html>', headers: { 'Content-Type' => 'text/html' })

          get :public_proxy, params: { path: 'test' }

          expect(response).to have_http_status(:ok)
          expect(a_request(:get, /localhost:4321/)).to have_been_made
        end
      end

      context 'with nil client_theme_config' do
        let!(:website) do
          create(:pwb_website,
            subdomain: 'nil-config',
            rendering_mode: 'client',
            client_theme_name: 'amsterdam',
            client_theme_config: nil
          )
        end

        before do
          allow(controller).to receive(:current_website).and_return(website)
          controller.instance_variable_set(:@current_website, website)
        end

        it 'falls back to default when config is nil' do
          stub_request(:get, /localhost:4321/)
            .to_return(status: 200, body: '<html>Default Astro</html>', headers: { 'Content-Type' => 'text/html' })

          get :public_proxy, params: { path: 'test' }

          expect(response).to have_http_status(:ok)
          expect(a_request(:get, /localhost:4321/)).to have_been_made
        end
      end
    end

    describe 'JWT token generation' do
      let!(:website) do
        create(:pwb_website, subdomain: 'client-site', rendering_mode: 'client', client_theme_name: 'amsterdam')
      end
      let(:user) { create(:pwb_user, website: website) }

      before do
        allow(controller).to receive(:current_website).and_return(website)
        allow(controller).to receive(:current_user).and_return(user)
        controller.instance_variable_set(:@current_website, website)
      end

      it 'generates valid JWT token' do
        token = controller.send(:generate_proxy_auth_token)

        decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
        payload = decoded.first

        expect(payload['user_id']).to eq(user.id)
        expect(payload['website_id']).to eq(website.id)
        expect(payload['exp']).to be > Time.current.to_i
      end
    end
  end
end
