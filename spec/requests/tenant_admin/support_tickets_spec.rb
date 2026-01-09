# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TenantAdmin::SupportTickets', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'tenant-support-test') }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:website_admin) { create(:pwb_user, :admin, website: website, email: 'websiteadmin@test.test') }
  let!(:platform_admin) { create(:pwb_user, :admin, website: website, email: 'platform@test.test') }

  before do
    # Allow platform admin access via env variable
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('platform@test.test')
    sign_in platform_admin
  end

  describe 'GET /tenant_admin/support_tickets' do
    context 'with no tickets' do
      it 'renders successfully' do
        get tenant_admin_support_tickets_path
        expect(response).to have_http_status(:success)
      end

      it 'shows empty state' do
        get tenant_admin_support_tickets_path
        expect(response.body).to include('No tickets found')
      end
    end

    context 'with existing tickets' do
      let!(:ticket) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: website_admin, subject: 'Platform help needed')
        end
      end

      it 'renders successfully' do
        get tenant_admin_support_tickets_path
        expect(response).to have_http_status(:success)
      end

      it 'displays ticket subject' do
        get tenant_admin_support_tickets_path
        expect(response.body).to include('Platform help needed')
      end

      it 'displays website subdomain' do
        get tenant_admin_support_tickets_path
        expect(response.body).to include('tenant-support-test')
      end
    end

    context 'with filters' do
      let!(:open_ticket) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: website_admin, subject: 'Open issue', status: :open)
        end
      end
      let!(:urgent_ticket) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, :urgent, website: website, creator: website_admin, subject: 'Urgent issue')
        end
      end

      it 'filters by status' do
        get tenant_admin_support_tickets_path, params: { status: 'open' }
        expect(response).to have_http_status(:success)
      end

      it 'filters by priority' do
        get tenant_admin_support_tickets_path, params: { priority: 'urgent' }
        expect(response).to have_http_status(:success)
      end

      it 'shows clear filter link when filters are applied' do
        get tenant_admin_support_tickets_path, params: { status: 'open' }
        expect(response.body).to include('Clear')
      end
    end

    context 'cross-tenant visibility' do
      let!(:website2) { create(:pwb_website, subdomain: 'other-tenant') }
      let!(:user2) { create(:pwb_user, website: website2) }
      let!(:ticket1) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: website_admin, subject: 'Ticket from tenant 1')
        end
      end
      let!(:ticket2) do
        ActsAsTenant.with_tenant(website2) do
          create(:pwb_support_ticket, website: website2, creator: user2, subject: 'Ticket from tenant 2')
        end
      end

      it 'shows tickets from all websites (platform admin view)' do
        get tenant_admin_support_tickets_path
        expect(response.body).to include('Ticket from tenant 1')
        expect(response.body).to include('Ticket from tenant 2')
      end
    end
  end

  describe 'GET /tenant_admin/support_tickets/:id' do
    let!(:ticket) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_support_ticket, website: website, creator: website_admin, subject: 'Detailed ticket')
      end
    end

    it 'renders successfully' do
      get tenant_admin_support_ticket_path(ticket)
      expect(response).to have_http_status(:success)
    end

    it 'displays ticket details' do
      get tenant_admin_support_ticket_path(ticket)
      expect(response.body).to include('Detailed ticket')
      expect(response.body).to include(ticket.ticket_number)
    end

    context 'with messages' do
      let!(:customer_message) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_ticket_message, support_ticket: ticket, website: website, user: website_admin,
                                      content: 'Customer message', from_platform_admin: false)
        end
      end
      let!(:platform_message) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_ticket_message, :from_platform, support_ticket: ticket, website: website, user: platform_admin,
                                                      content: 'Platform reply')
        end
      end
      let!(:internal_note) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_ticket_message, :internal_note, support_ticket: ticket, website: website, user: platform_admin,
                                                      content: 'Internal team note')
        end
      end

      it 'displays all messages including internal notes' do
        get tenant_admin_support_ticket_path(ticket)
        expect(response.body).to include('Customer message')
        expect(response.body).to include('Platform reply')
        expect(response.body).to include('Internal team note')
      end
    end
  end

  describe 'PATCH /tenant_admin/support_tickets/:id/assign' do
    let!(:ticket) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_support_ticket, website: website, creator: website_admin)
      end
    end

    it 'assigns the ticket to a user' do
      patch assign_tenant_admin_support_ticket_path(ticket), params: { user_id: platform_admin.id }
      expect(ticket.reload.assigned_to).to eq(platform_admin)
    end

    it 'sets the status to in_progress' do
      patch assign_tenant_admin_support_ticket_path(ticket), params: { user_id: platform_admin.id }
      expect(ticket.reload).to be_status_in_progress
    end

    it 'redirects to the ticket' do
      patch assign_tenant_admin_support_ticket_path(ticket), params: { user_id: platform_admin.id }
      expect(response).to redirect_to(tenant_admin_support_ticket_path(ticket))
    end
  end

  describe 'PATCH /tenant_admin/support_tickets/:id/change_status' do
    let!(:ticket) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_support_ticket, website: website, creator: website_admin, status: :open)
      end
    end

    it 'changes the ticket status' do
      patch change_status_tenant_admin_support_ticket_path(ticket), params: { status: 'resolved' }
      expect(ticket.reload).to be_status_resolved
    end

    it 'sets resolved_at when resolving' do
      patch change_status_tenant_admin_support_ticket_path(ticket), params: { status: 'resolved' }
      expect(ticket.reload.resolved_at).to be_present
    end

    it 'sets closed_at when closing' do
      patch change_status_tenant_admin_support_ticket_path(ticket), params: { status: 'closed' }
      expect(ticket.reload.closed_at).to be_present
    end

    it 'redirects to the ticket' do
      patch change_status_tenant_admin_support_ticket_path(ticket), params: { status: 'in_progress' }
      expect(response).to redirect_to(tenant_admin_support_ticket_path(ticket))
    end
  end

  describe 'POST /tenant_admin/support_tickets/:id/add_message' do
    let!(:ticket) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_support_ticket, website: website, creator: website_admin)
      end
    end

    context 'adding a public reply' do
      it 'adds a message marked as from platform' do
        expect do
          post add_message_tenant_admin_support_ticket_path(ticket),
               params: { message: { content: 'Platform response' } }
        end.to change(Pwb::TicketMessage, :count).by(1)

        # The newly created message should be from platform
        new_message = ticket.messages.order(created_at: :desc).first
        expect(new_message.from_platform_admin).to be true
        expect(new_message.content).to eq('Platform response')
      end

      it 'updates the ticket to waiting_on_customer when open' do
        ticket.update!(status: :open)
        post add_message_tenant_admin_support_ticket_path(ticket),
             params: { message: { content: 'We are looking into this' } }
        # Platform replies to open tickets set status to waiting_on_customer
        expect(ticket.reload).to be_status_waiting_on_customer
      end
    end

    context 'adding an internal note' do
      it 'creates an internal note' do
        expect do
          post add_message_tenant_admin_support_ticket_path(ticket),
               params: { message: { content: 'Internal discussion', internal_note: '1' } }
        end.to change(Pwb::TicketMessage, :count).by(1)

        # The newly created message should be an internal note
        new_message = ticket.messages.order(created_at: :desc).first
        expect(new_message.internal_note).to be true
        expect(new_message.content).to eq('Internal discussion')
      end
    end

    context 'with empty content' do
      it 'does not create a message' do
        expect do
          post add_message_tenant_admin_support_ticket_path(ticket),
               params: { message: { content: '' } }
        end.not_to change(Pwb::TicketMessage, :count)
      end
    end
  end
end
