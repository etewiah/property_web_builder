# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::Inbox', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'inbox-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@inbox-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  describe 'GET /site_admin/inbox' do
    context 'with no contacts or messages' do
      it 'renders successfully' do
        get site_admin_inbox_index_path, headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
        expect(response).to have_http_status(:success)
      end

      it 'shows empty state' do
        get site_admin_inbox_index_path, headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
        expect(response.body).to include('No contacts with messages')
      end
    end

    context 'with contacts that have messages' do
      let!(:contact) do
        ActsAsTenant.with_tenant(website) do
          create(:contact, website: website, first_name: 'John', last_name: 'Doe', primary_email: 'john@example.com')
        end
      end
      let!(:message1) do
        ActsAsTenant.with_tenant(website) do
          create(:message, website: website, contact: contact, content: 'First message', read: false)
        end
      end
      let!(:message2) do
        ActsAsTenant.with_tenant(website) do
          create(:message, website: website, contact: contact, content: 'Second message', read: true)
        end
      end

      it 'renders successfully' do
        get site_admin_inbox_index_path, headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
        expect(response).to have_http_status(:success)
      end

      it 'displays contact name' do
        get site_admin_inbox_index_path, headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
        expect(response.body).to include('John')
      end

      it 'displays message count' do
        get site_admin_inbox_index_path, headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
        expect(response.body).to include('2 messages')
      end

      # This test specifically catches the instance-dependent scope bug
      it 'can join contacts with messages without ArgumentError' do
        expect do
          get site_admin_inbox_index_path, headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
        end.not_to raise_error
      end
    end

    context 'with orphan messages (no contact)' do
      let!(:orphan_message) do
        ActsAsTenant.with_tenant(website) do
          create(:message, website: website, contact: nil, origin_email: 'orphan@example.com')
        end
      end

      it 'displays orphan message count' do
        get site_admin_inbox_index_path, headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
        expect(response.body).to include('1 message without contact')
      end
    end

    context 'with search' do
      let!(:contact1) do
        ActsAsTenant.with_tenant(website) do
          create(:contact, website: website, first_name: 'Alice', primary_email: 'alice@example.com')
        end
      end
      let!(:contact2) do
        ActsAsTenant.with_tenant(website) do
          create(:contact, website: website, first_name: 'Bob', primary_email: 'bob@example.com')
        end
      end
      let!(:message1) do
        ActsAsTenant.with_tenant(website) do
          create(:message, website: website, contact: contact1)
        end
      end
      let!(:message2) do
        ActsAsTenant.with_tenant(website) do
          create(:message, website: website, contact: contact2)
        end
      end

      it 'filters contacts by name' do
        get site_admin_inbox_index_path, params: { search: 'alice' }, headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Alice')
        expect(response.body).not_to include('Bob')
      end

      it 'filters contacts by email' do
        get site_admin_inbox_index_path, params: { search: 'bob@' }, headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Bob')
        expect(response.body).not_to include('Alice')
      end
    end

    context 'multi-tenant isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-inbox') }
      let!(:other_contact) do
        ActsAsTenant.with_tenant(other_website) do
          create(:contact, website: other_website, first_name: 'OtherTenant')
        end
      end
      let!(:other_message) do
        ActsAsTenant.with_tenant(other_website) do
          create(:message, website: other_website, contact: other_contact)
        end
      end

      let!(:our_contact) do
        ActsAsTenant.with_tenant(website) do
          create(:contact, website: website, first_name: 'OurTenant')
        end
      end
      let!(:our_message) do
        ActsAsTenant.with_tenant(website) do
          create(:message, website: website, contact: our_contact)
        end
      end

      it 'only shows contacts from current website' do
        get site_admin_inbox_index_path, headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
        expect(response.body).to include('OurTenant')
        expect(response.body).not_to include('OtherTenant')
      end
    end
  end

  describe 'GET /site_admin/inbox/:id' do
    let!(:contact) do
      ActsAsTenant.with_tenant(website) do
        create(:contact, website: website, first_name: 'Jane', primary_email: 'jane@example.com')
      end
    end
    let!(:message1) do
      ActsAsTenant.with_tenant(website) do
        create(:message, website: website, contact: contact, content: 'Hello there', read: false, created_at: 1.hour.ago)
      end
    end
    let!(:message2) do
      ActsAsTenant.with_tenant(website) do
        create(:message, website: website, contact: contact, content: 'Follow up', read: false, created_at: 30.minutes.ago)
      end
    end

    it 'renders successfully' do
      get conversation_site_admin_inbox_path(contact), headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
      expect(response).to have_http_status(:success)
    end

    it 'displays the conversation' do
      get conversation_site_admin_inbox_path(contact), headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
      expect(response.body).to include('Hello there')
      expect(response.body).to include('Follow up')
    end

    it 'marks messages as read' do
      expect(message1.read).to be false
      expect(message2.read).to be false

      get conversation_site_admin_inbox_path(contact), headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }

      expect(message1.reload.read).to be true
      expect(message2.reload.read).to be true
    end

    it 'creates audit log entries for read messages' do
      expect do
        get conversation_site_admin_inbox_path(contact), headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
      end.to change(Pwb::AuthAuditLog, :count).by(2)
    end

    context 'contact from another website' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-inbox-show') }
      let!(:other_contact) do
        ActsAsTenant.with_tenant(other_website) do
          create(:contact, website: other_website)
        end
      end

      it 'returns 404' do
        get conversation_site_admin_inbox_path(other_contact), headers: { 'HTTP_HOST' => 'inbox-test.test.localhost' }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
