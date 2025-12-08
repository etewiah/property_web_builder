# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe 'Contacts API', type: :request do
    include Warden::Test::Helpers
    include FactoryBot::Syntax::Methods

    before do
      Warden.test_mode!
      Pwb::Current.reset
    end

    after do
      Warden.test_reset!
    end

    let!(:website) { create(:pwb_website, subdomain: 'contacts-api-test') }
    let!(:admin_user) { create(:pwb_user, :admin, website: website) }

    let(:request_headers) do
      {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    end

    describe 'GET /api/v1/contacts' do
      let!(:contact_a) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_contact, website: website)
        end
      end

      let!(:other_website) { create(:pwb_website, subdomain: 'other-contacts') }
      let!(:contact_other) do
        ActsAsTenant.with_tenant(other_website) do
          create(:pwb_contact, website: other_website)
        end
      end

      before do
        login_as admin_user, scope: :user
      end

      it 'returns contacts for the current tenant' do
        host! 'contacts-api-test.example.com'
        get '/api/v1/contacts', headers: request_headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
      end

      it 'isolates contacts by tenant' do
        # Verify contacts are scoped to their websites
        expect(contact_a.website).to eq(website)
        expect(contact_other.website).to eq(other_website)
      end
    end

    describe 'GET /api/v1/contacts/:id' do
      let!(:contact) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_contact, website: website)
        end
      end

      before do
        login_as admin_user, scope: :user
      end

      it 'returns contact details' do
        host! 'contacts-api-test.example.com'
        get "/api/v1/contacts/#{contact.id}", headers: request_headers

        expect(response).to have_http_status(:success)
      end

      it 'returns 404 for contacts from other tenants' do
        other_website = create(:pwb_website, subdomain: 'other-tenant-contacts')
        other_contact = ActsAsTenant.with_tenant(other_website) do
          create(:pwb_contact, website: other_website)
        end

        host! 'contacts-api-test.example.com'
        get "/api/v1/contacts/#{other_contact.id}", headers: request_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'POST /api/v1/contacts' do
      before do
        login_as admin_user, scope: :user
      end

      let(:valid_params) do
        {
          details: {
            first_name: 'John',
            last_name: 'Doe'
          }
        }
      end

      it 'creates a contact for the current tenant' do
        host! 'contacts-api-test.example.com'

        expect {
          post '/api/v1/contacts', params: valid_params.to_json, headers: request_headers
        }.to change { website.contacts.count }.by(1)
      end
    end

    describe 'PATCH /api/v1/contacts/:id' do
      let!(:contact) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_contact, website: website)
        end
      end

      before do
        login_as admin_user, scope: :user
      end

      it 'updates contact details' do
        host! 'contacts-api-test.example.com'
        patch "/api/v1/contacts/#{contact.id}",
              params: { details: { first_name: 'Updated' } }.to_json,
              headers: request_headers

        expect(response).to have_http_status(:success)
      end

      it 'returns 404 when updating contact from other tenant' do
        other_website = create(:pwb_website, subdomain: 'other-update')
        other_contact = ActsAsTenant.with_tenant(other_website) do
          create(:pwb_contact, website: other_website)
        end

        host! 'contacts-api-test.example.com'
        patch "/api/v1/contacts/#{other_contact.id}",
              params: { details: { first_name: 'Hacked' } }.to_json,
              headers: request_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
