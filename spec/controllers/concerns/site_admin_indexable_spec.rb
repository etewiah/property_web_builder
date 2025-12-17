# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdminIndexable do
  describe 'module structure' do
    it 'defines class attributes' do
      expect(SiteAdminIndexable).to be_a(Module)
    end
  end

  describe 'included in a controller' do
    # Test through an actual controller that uses the concern
    let(:controller_class) { SiteAdmin::ContactsController }

    it 'has indexable_model_class set' do
      expect(controller_class.indexable_model_class).to eq(Pwb::Contact)
    end

    it 'has indexable_search_columns set' do
      expect(controller_class.indexable_search_columns).to eq(%i[primary_email first_name last_name])
    end

    it 'has indexable_limit set' do
      expect(controller_class.indexable_limit).to eq(100)
    end

    it 'has default order' do
      expect(controller_class.indexable_order).to eq({ created_at: :desc })
    end
  end
end

# Integration test through request specs
RSpec.describe 'SiteAdminIndexable integration', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'indexable-int-test') }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@indexable-int.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'ContactsController using SiteAdminIndexable' do
    before do
      @contact1 = Pwb::Contact.create!(
        website_id: website.id,
        primary_email: 'john@example.com',
        first_name: 'John',
        last_name: 'Doe'
      )
      @contact2 = Pwb::Contact.create!(
        website_id: website.id,
        primary_email: 'jane@example.com',
        first_name: 'Jane',
        last_name: 'Smith'
      )
    end

    describe 'GET /site_admin/contacts' do
      it 'renders index successfully' do
        get site_admin_contacts_path,
            headers: { 'HTTP_HOST' => 'indexable-int-test.e2e.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'returns contacts scoped to website' do
        # Create contact for different website
        other_website = create(:pwb_website, subdomain: 'other-indexable-int')
        Pwb::Contact.create!(
          website_id: other_website.id,
          primary_email: 'other@example.com',
          first_name: 'Other'
        )

        get site_admin_contacts_path,
            headers: { 'HTTP_HOST' => 'indexable-int-test.e2e.localhost' }

        expect(response).to have_http_status(:success)
        # Should only show our website's contacts
        expect(response.body).to include('john@example.com')
        expect(response.body).to include('jane@example.com')
        expect(response.body).not_to include('other@example.com')
      end

      it 'filters by search parameter' do
        get site_admin_contacts_path,
            params: { search: 'john' },
            headers: { 'HTTP_HOST' => 'indexable-int-test.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('john@example.com')
        expect(response.body).not_to include('jane@example.com')
      end
    end

    describe 'GET /site_admin/contacts/:id' do
      it 'renders show successfully' do
        get site_admin_contact_path(@contact1),
            headers: { 'HTTP_HOST' => 'indexable-int-test.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('john@example.com')
      end
    end
  end

  describe 'MessagesController using SiteAdminIndexable' do
    before do
      @message = Pwb::Message.create!(
        website_id: website.id,
        origin_email: 'sender@example.com',
        content: 'Test message content'
      )
    end

    describe 'GET /site_admin/messages' do
      it 'renders index successfully' do
        get site_admin_messages_path,
            headers: { 'HTTP_HOST' => 'indexable-int-test.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('sender@example.com')
      end

      it 'filters by search parameter' do
        get site_admin_messages_path,
            params: { search: 'sender@' },
            headers: { 'HTTP_HOST' => 'indexable-int-test.e2e.localhost' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('sender@example.com')
      end
    end
  end
end
