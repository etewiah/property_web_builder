# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe 'Agency API', type: :request do
    include Warden::Test::Helpers
    include FactoryBot::Syntax::Methods

    before do
      Warden.test_mode!
      Pwb::Current.reset
    end

    after do
      Warden.test_reset!
    end

    let!(:website) { create(:pwb_website, subdomain: 'agency-test') }
    let!(:agency) { website.agency }
    let!(:admin_user) { create(:pwb_user, :admin) }

    let(:request_headers) do
      {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    end

    describe 'GET /api/v1/agency' do
      context 'with signed in admin user' do
        before do
          login_as admin_user, scope: :user
        end

        it 'returns agency details for the current tenant' do
          host! 'agency-test.example.com'
          get '/api/v1/agency'

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)
          expect(json['agency']).to be_present
          expect(json['agency']['company_name']).to eq(agency.company_name)
        end

        it 'returns correct JSON structure' do
          host! 'agency-test.example.com'
          get '/api/v1/agency'

          expect(response).to have_http_status(:success)
          expect(response.body).to have_json_path('agency')
          expect(response.body).to have_json_path('setup/currencyFieldKeys')
        end
      end

      context 'without signed in user' do
        it 'redirects to sign_in page' do
          host! 'agency-test.example.com'
          get '/api/v1/agency'

          expect(response).to have_http_status(:redirect)
        end
      end
    end

    describe 'PUT /api/v1/agency' do
      before do
        login_as admin_user, scope: :user
      end

      it 'updates agency settings for the current tenant' do
        host! 'agency-test.example.com'

        agency_params = {
          agency: {
            company_name: 'Updated Company Name',
            supported_locales: ['fr', 'es'],
            social_media: {
              twitter: 'http://twitter.com/test',
              youtube: ''
            }
          }
        }.to_json

        put '/api/v1/agency', params: agency_params, headers: request_headers

        expect(response).to have_http_status(:success)
        agency.reload
        expect(agency.company_name).to eq('Updated Company Name')
        expect(agency.social_media).to eq({ 'twitter' => 'http://twitter.com/test', 'youtube' => '' })
      end
    end

    describe 'multi-tenant agency isolation' do
      let!(:website1) { create(:pwb_website, subdomain: 'agency-tenant1') }
      let!(:website2) { create(:pwb_website, subdomain: 'agency-tenant2') }
      let!(:agency1) { website1.agency.tap { |a| a.update!(company_name: 'Agency One') } }
      let!(:agency2) { website2.agency.tap { |a| a.update!(company_name: 'Agency Two') } }

      before do
        login_as admin_user, scope: :user
      end

      it 'returns correct agency for each tenant' do
        # Verify each website has its own agency
        expect(agency1.website).to eq(website1)
        expect(agency2.website).to eq(website2)

        # Verify agency company names are different
        expect(agency1.company_name).to eq('Agency One')
        expect(agency2.company_name).to eq('Agency Two')

        # Verify Pwb::Current can switch between tenants
        Pwb::Current.website = website1
        expect(Pwb::Current.website.agency.company_name).to eq('Agency One')

        Pwb::Current.reset
        Pwb::Current.website = website2
        expect(Pwb::Current.website.agency.company_name).to eq('Agency Two')
      end

      it 'updates only the agency for the current tenant' do
        host! 'agency-tenant1.example.com'

        agency_params = {
          agency: {
            company_name: 'Updated Agency One'
          }
        }.to_json

        put '/api/v1/agency', params: agency_params, headers: request_headers

        expect(response).to have_http_status(:success)
        agency1.reload
        agency2.reload
        expect(agency1.company_name).to eq('Updated Agency One')
        expect(agency2.company_name).to eq('Agency Two') # unchanged
      end
    end
  end
end
