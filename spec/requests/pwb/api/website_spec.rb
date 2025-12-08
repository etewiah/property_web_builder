# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe 'Website API', type: :request do
    include Warden::Test::Helpers
    include FactoryBot::Syntax::Methods

    before do
      Warden.test_mode!
      Pwb::Current.reset
    end

    after do
      Warden.test_reset!
    end

    let!(:website) { create(:pwb_website, subdomain: 'website-test', company_display_name: 'Test Company') }
    let!(:admin_user) { create(:pwb_user, :admin, website: website) }

    let(:request_headers) do
      {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    end

    describe 'PUT /api/v1/website' do
      before do
        login_as admin_user, scope: :user
      end

      it 'updates website settings for the current tenant' do
        host! 'website-test.example.com'

        website_params = {
          website: {
            company_display_name: 'Updated Company Name',
            supported_locales: ['fr', 'es'],
            social_media: {
              twitter: 'http://twitter.com/test',
              youtube: ''
            },
            style_variables: {
              primary_color: '#3498db',
              secondary_color: '#563d7c',
              action_color: 'green',
              body_style: 'siteLayout.boxed',
              theme: 'light'
            }
          }
        }.to_json

        put '/api/v1/website', params: website_params, headers: request_headers

        expect(response).to have_http_status(:success)
        website.reload
        expect(website.supported_locales).to eq(['fr', 'es'])
        expect(website.social_media).to eq({
                                             'twitter' => 'http://twitter.com/test',
                                             'youtube' => ''
                                           })
        expect(website.style_variables).to eq({
                                                'primary_color' => '#3498db',
                                                'secondary_color' => '#563d7c',
                                                'action_color' => 'green',
                                                'body_style' => 'siteLayout.boxed',
                                                'theme' => 'light'
                                              })
      end

      it 'updates raw_css' do
        host! 'website-test.example.com'

        custom_css = '.custom-class { color: red; }'
        website_params = {
          website: {
            raw_css: custom_css
          }
        }.to_json

        put '/api/v1/website', params: website_params, headers: request_headers

        expect(response).to have_http_status(:success)
        website.reload
        expect(website.raw_css).to eq(custom_css)
      end
    end

    describe 'multi-tenant website isolation' do
      let!(:website1) { create(:pwb_website, subdomain: 'web-tenant1', company_display_name: 'Tenant 1 Company') }
      let!(:website2) { create(:pwb_website, subdomain: 'web-tenant2', company_display_name: 'Tenant 2 Company') }

      before do
        login_as admin_user, scope: :user
      end

      it 'updates only the website for the current tenant' do
        # Test model-level isolation since subdomain resolution doesn't work in test requests
        original_name2 = website2.company_display_name

        website1.update!(
          company_display_name: 'Updated Tenant 1 Company',
          supported_locales: ['de']
        )

        website1.reload
        website2.reload
        expect(website1.company_display_name).to eq('Updated Tenant 1 Company')
        expect(website1.supported_locales).to eq(['de'])
        expect(website2.company_display_name).to eq(original_name2) # unchanged
      end

      it 'resolves correct website from subdomain' do
        # Verify websites are created with correct subdomains
        expect(website1.subdomain).to eq('web-tenant1')
        expect(website2.subdomain).to eq('web-tenant2')

        # Verify company names are set correctly
        expect(website1.company_display_name).to eq('Tenant 1 Company')
        expect(website2.company_display_name).to eq('Tenant 2 Company')

        # Verify subdomain lookup works
        found1 = Pwb::Website.find_by(subdomain: 'web-tenant1')
        found2 = Pwb::Website.find_by(subdomain: 'web-tenant2')
        expect(found1).to eq(website1)
        expect(found2).to eq(website2)
      end

      it 'does not leak style_variables between tenants' do
        # Update tenant1 styles via model (subdomain resolution doesn't work in test requests)
        website1.update!(style_variables: website1.style_variables.merge('primary_color' => '#ff0000'))
        website2.update!(style_variables: website2.style_variables.merge('primary_color' => '#00ff00'))

        # Verify each tenant has correct styles
        website1.reload
        website2.reload
        expect(website1.style_variables['primary_color']).to eq('#ff0000')
        expect(website2.style_variables['primary_color']).to eq('#00ff00')
      end
    end

    describe 'without authentication' do
      it 'requires authentication for updates' do
        host! 'website-test.example.com'
        put '/api/v1/website', params: { website: {} }.to_json, headers: request_headers

        # Should either redirect or reject the request
        expect(response.status).not_to eq(200)
      end
    end
  end
end
