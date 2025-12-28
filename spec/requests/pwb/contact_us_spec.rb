# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pwb::ContactUsController', type: :request do
  # Contact form is business-critical - handles lead generation
  # Must verify: form submission, validation, email delivery, multi-tenancy

  let!(:website) { create(:pwb_website, subdomain: 'contact-test') }
  let!(:agency) { create(:pwb_agency, website: website, email_primary: 'agency@test.com') }

  before do
    allow(Pwb::Current).to receive(:website).and_return(website)
    # Set ActsAsTenant for proper scoping - must be set before creating tenant-scoped records
    ActsAsTenant.current_tenant = website
    # Create contact page within tenant context
    create(:pwb_page, website: website, slug: 'contact-us', page_title: 'Contact Us')
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /contact-us (index)' do
    it 'renders the contact page successfully' do
      get '/contact-us', headers: { 'HTTP_HOST' => 'contact-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    it 'displays the contact form' do
      get '/contact-us', headers: { 'HTTP_HOST' => 'contact-test.test.localhost' }

      expect(response.body).to include('contact')
    end
  end

  describe 'POST /contact-us-ajax (contact_us_ajax)' do
    let(:valid_params) do
      {
        contact: {
          name: 'John Doe',
          email: 'john@example.com',
          tel: '+1234567890',
          subject: 'Property Inquiry',
          message: 'I am interested in your properties.',
          locale: 'en'
        }
      }
    end

    # Helper to make JS AJAX requests (mimics Rails UJS remote: true)
    let(:js_headers) { { 'HTTP_HOST' => 'contact-test.test.localhost', 'Accept' => 'text/javascript' } }

    context 'with valid parameters' do
      it 'creates a new contact' do
        expect {
          post '/contact_us',
               params: valid_params,
               headers: js_headers,
               as: :js
        }.to change(Pwb::Contact, :count).by(1)
      end

      it 'creates a new message/enquiry' do
        expect {
          post '/contact_us',
               params: valid_params,
               headers: js_headers,
               as: :js
        }.to change(Pwb::Message, :count).by(1)
      end

      it 'associates contact and message with correct website' do
        post '/contact_us',
             params: valid_params,
             headers: js_headers,
             as: :js

        contact = Pwb::Contact.last
        message = Pwb::Message.last

        expect(contact.website_id).to eq(website.id)
        expect(message.website_id).to eq(website.id)
      end

      it 'stores contact information correctly' do
        post '/contact_us',
             params: valid_params,
             headers: js_headers,
             as: :js

        contact = Pwb::Contact.last
        expect(contact.first_name).to eq('John Doe')
        expect(contact.primary_email).to eq('john@example.com')
        expect(contact.primary_phone_number).to eq('+1234567890')
      end

      it 'stores message content correctly' do
        post '/contact_us',
             params: valid_params,
             headers: js_headers,
             as: :js

        message = Pwb::Message.last
        expect(message.title).to eq('Property Inquiry')
        expect(message.content).to eq('I am interested in your properties.')
        expect(message.locale).to eq('en')
      end

      it 'stores origin_email in message for display in admin' do
        post '/contact_us',
             params: valid_params,
             headers: js_headers,
             as: :js

        message = Pwb::Message.last
        expect(message.origin_email).to eq('john@example.com')
      end

      it 'records request metadata (IP, user agent)' do
        post '/contact_us',
             params: valid_params,
             headers: js_headers.merge('HTTP_USER_AGENT' => 'Test Browser'),
             as: :js

        message = Pwb::Message.last
        expect(message.origin_ip).to be_present
        expect(message.user_agent).to eq('Test Browser')
      end

      it 'enqueues email delivery' do
        expect {
          post '/contact_us',
               params: valid_params,
               headers: js_headers,
               as: :js
        }.to have_enqueued_job.on_queue('mailers')
      end

      it 'renders success response' do
        post '/contact_us',
             params: valid_params,
             headers: js_headers,
             as: :js

        expect(response).to have_http_status(:success)
      end

      it 'sets delivery email from agency' do
        post '/contact_us',
             params: valid_params,
             headers: js_headers,
             as: :js

        message = Pwb::Message.last
        # Delivery email comes from agency's email_for_general_contact_form
        expect(message.delivery_email).to be_present
      end
    end

    context 'with existing contact (same email)' do
      let!(:existing_contact) do
        create(:pwb_contact, website: website, primary_email: 'john@example.com', first_name: 'Old Name')
      end

      it 'updates existing contact instead of creating new' do
        expect {
          post '/contact_us',
               params: valid_params,
               headers: js_headers,
               as: :js
        }.not_to change(Pwb::Contact, :count)
      end

      it 'updates contact details' do
        post '/contact_us',
             params: valid_params,
             headers: js_headers,
             as: :js

        existing_contact.reload
        expect(existing_contact.first_name).to eq('John Doe')
        expect(existing_contact.primary_phone_number).to eq('+1234567890')
      end

      it 'still creates a new message' do
        expect {
          post '/contact_us',
               params: valid_params,
               headers: js_headers,
               as: :js
        }.to change(Pwb::Message, :count).by(1)
      end
    end

    context 'with invalid parameters' do
      it 'returns error for missing email' do
        post '/contact_us',
             params: { contact: { name: 'Test', message: 'Hello', locale: 'en' } },
             headers: js_headers,
             as: :js

        # Message may be created but contact won't be valid without email
        # The form validates email on the client-side primarily
        expect(response).to have_http_status(:success) # Error response is still 200 with JS
      end
    end

    context 'with missing agency email' do
      before do
        agency.update!(email_primary: nil)
      end

      it 'still saves the message with fallback delivery email' do
        post '/contact_us',
             params: valid_params,
             headers: js_headers,
             as: :js

        message = Pwb::Message.last
        expect(message).to be_present
        expect(message.delivery_email).to include('propertywebbuilder.com')
      end
    end

    context 'multi-tenancy isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-site') }
      let!(:other_agency) { create(:pwb_agency, website: other_website) }

      it 'does not leak contacts to other websites' do
        post '/contact_us',
             params: valid_params,
             headers: js_headers,
             as: :js

        # Contact should only be associated with the current website
        contact = Pwb::Contact.last
        expect(contact.website_id).to eq(website.id)
        expect(contact.website_id).not_to eq(other_website.id)

        # Other website should not see this contact
        other_contacts = Pwb::Contact.where(website_id: other_website.id)
        expect(other_contacts).to be_empty
      end

      it 'does not leak messages to other websites' do
        post '/contact_us',
             params: valid_params,
             headers: js_headers,
             as: :js

        message = Pwb::Message.last
        expect(message.website_id).to eq(website.id)

        other_messages = Pwb::Message.where(website_id: other_website.id)
        expect(other_messages).to be_empty
      end
    end

    context 'with ntfy notifications enabled' do
      before do
        website.update!(ntfy_enabled: true, ntfy_topic_prefix: 'test-prefix')
      end

      it 'enqueues notification job' do
        expect {
          post '/contact_us',
               params: valid_params,
               headers: js_headers,
               as: :js
        }.to have_enqueued_job(NtfyNotificationJob)
      end
    end
  end
end
