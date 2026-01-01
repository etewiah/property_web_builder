# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::SupportTickets', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'support-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@support-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  describe 'GET /site_admin/support_tickets' do
    context 'with no tickets' do
      it 'renders successfully' do
        get site_admin_support_tickets_path, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(response).to have_http_status(:success)
      end

      it 'shows empty state' do
        get site_admin_support_tickets_path, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(response.body).to include('No support tickets')
      end
    end

    context 'with existing tickets' do
      let!(:ticket) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: admin_user, subject: 'Help with billing')
        end
      end

      it 'renders successfully' do
        get site_admin_support_tickets_path, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(response).to have_http_status(:success)
      end

      it 'displays ticket subject' do
        get site_admin_support_tickets_path, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(response.body).to include('Help with billing')
      end

      it 'displays ticket number' do
        get site_admin_support_tickets_path, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(response.body).to include(ticket.ticket_number)
      end
    end

    context 'with status filter' do
      let!(:open_ticket) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: admin_user, subject: 'Open ticket', status: :open)
        end
      end
      let!(:resolved_ticket) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, :resolved, website: website, creator: admin_user, subject: 'Resolved ticket')
        end
      end

      it 'filters by status' do
        get site_admin_support_tickets_path, params: { status: 'resolved' }, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Resolved ticket')
        expect(response.body).not_to include('Open ticket')
      end
    end

    context 'multi-tenant isolation' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-support') }
      let!(:other_user) { create(:pwb_user, website: other_website) }
      let!(:other_ticket) do
        ActsAsTenant.with_tenant(other_website) do
          create(:pwb_support_ticket, website: other_website, creator: other_user, subject: 'Other tenant ticket')
        end
      end
      let!(:our_ticket) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: admin_user, subject: 'Our tenant ticket')
        end
      end

      it 'only shows tickets from current website' do
        get site_admin_support_tickets_path, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(response.body).to include('Our tenant ticket')
        expect(response.body).not_to include('Other tenant ticket')
      end
    end
  end

  describe 'GET /site_admin/support_tickets/new' do
    it 'renders successfully' do
      get new_site_admin_support_ticket_path, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
      expect(response).to have_http_status(:success)
    end

    it 'shows the form' do
      get new_site_admin_support_ticket_path, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
      expect(response.body).to include('Create Support Ticket')
      expect(response.body).to include('Subject')
      expect(response.body).to include('Description')
    end

    context 'without authentication' do
      before { sign_out admin_user }

      it 'redirects or shows error' do
        get new_site_admin_support_ticket_path, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        # Should be redirected or forbidden since we need auth for ticket creation
        expect(response).to have_http_status(:forbidden).or have_http_status(:redirect)
      end
    end
  end

  describe 'POST /site_admin/support_tickets' do
    let(:valid_params) do
      {
        pwb_support_ticket: {
          subject: 'Need help with my listing',
          description: 'My property is not showing up correctly',
          category: 'technical',
          priority: 'normal'
        }
      }
    end

    it 'creates a new ticket' do
      expect {
        post site_admin_support_tickets_path, params: valid_params, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
      }.to change(Pwb::SupportTicket, :count).by(1)
    end

    it 'redirects to the ticket' do
      post site_admin_support_tickets_path, params: valid_params, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
      expect(response).to redirect_to(site_admin_support_ticket_path(Pwb::SupportTicket.last))
    end

    it 'sets the creator to current user' do
      post site_admin_support_tickets_path, params: valid_params, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
      expect(Pwb::SupportTicket.last.creator).to eq(admin_user)
    end

    it 'generates a ticket number' do
      post site_admin_support_tickets_path, params: valid_params, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
      expect(Pwb::SupportTicket.last.ticket_number).to match(/^TKT-[A-Z0-9]{8}$/)
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          pwb_support_ticket: {
            subject: '',
            description: 'Missing subject'
          }
        }
      end

      it 'does not create a ticket' do
        expect {
          post site_admin_support_tickets_path, params: invalid_params, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        }.not_to change(Pwb::SupportTicket, :count)
      end

      it 'renders the form with errors' do
        post site_admin_support_tickets_path, params: invalid_params, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("can&#39;t be blank")
      end
    end

    context 'without authentication' do
      before { sign_out admin_user }

      it 'does not create a ticket' do
        expect {
          post site_admin_support_tickets_path, params: valid_params, headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        }.not_to change(Pwb::SupportTicket, :count)
      end
    end
  end

  describe 'GET /site_admin/support_tickets/:id' do
    let!(:ticket) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_support_ticket, website: website, creator: admin_user, subject: 'Test ticket')
      end
    end

    it 'renders successfully' do
      get site_admin_support_ticket_path(ticket), headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
      expect(response).to have_http_status(:success)
    end

    it 'displays ticket details' do
      get site_admin_support_ticket_path(ticket), headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
      expect(response.body).to include('Test ticket')
      expect(response.body).to include(ticket.ticket_number)
    end

    context 'with messages' do
      let!(:message) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_ticket_message, support_ticket: ticket, website: website, user: admin_user, content: 'Test reply')
        end
      end

      it 'displays messages' do
        get site_admin_support_ticket_path(ticket), headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(response.body).to include('Test reply')
      end
    end

    context 'with internal notes' do
      let!(:internal_note) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_ticket_message, :internal_note, support_ticket: ticket, website: website, user: admin_user, content: 'Secret internal note')
        end
      end

      it 'does not display internal notes to website admins' do
        get site_admin_support_ticket_path(ticket), headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(response.body).not_to include('Secret internal note')
      end
    end

    context 'ticket from another website' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-support-show') }
      let!(:other_user) { create(:pwb_user, website: other_website) }
      let!(:other_ticket) do
        ActsAsTenant.with_tenant(other_website) do
          create(:pwb_support_ticket, website: other_website, creator: other_user)
        end
      end

      it 'returns 404' do
        get site_admin_support_ticket_path(other_ticket), headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /site_admin/support_tickets/:id/add_message' do
    let!(:ticket) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_support_ticket, website: website, creator: admin_user)
      end
    end

    it 'adds a message to the ticket' do
      expect {
        post add_message_site_admin_support_ticket_path(ticket),
             params: { message: { content: 'New reply' } },
             headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
      }.to change(Pwb::TicketMessage, :count).by(1)
    end

    it 'redirects to the ticket' do
      post add_message_site_admin_support_ticket_path(ticket),
           params: { message: { content: 'New reply' } },
           headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
      expect(response).to redirect_to(site_admin_support_ticket_path(ticket))
    end

    it 'sets from_platform_admin to false' do
      post add_message_site_admin_support_ticket_path(ticket),
           params: { message: { content: 'New reply' } },
           headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
      expect(Pwb::TicketMessage.last.from_platform_admin).to be false
    end

    context 'when ticket is waiting_on_customer' do
      before { ticket.update!(status: :waiting_on_customer) }

      it 'reopens the ticket' do
        post add_message_site_admin_support_ticket_path(ticket),
             params: { message: { content: 'Customer reply' } },
             headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(ticket.reload).to be_status_open
      end
    end

    context 'with empty message' do
      it 'does not add a message' do
        expect {
          post add_message_site_admin_support_ticket_path(ticket),
               params: { message: { content: '' } },
               headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        }.not_to change(Pwb::TicketMessage, :count)
      end

      it 'redirects with alert' do
        post add_message_site_admin_support_ticket_path(ticket),
             params: { message: { content: '' } },
             headers: { 'HTTP_HOST' => 'support-test.test.localhost' }
        expect(response).to redirect_to(site_admin_support_ticket_path(ticket))
        expect(flash[:alert]).to be_present
      end
    end
  end
end
