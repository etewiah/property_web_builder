# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_support_tickets
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  assigned_at                :datetime
#  category                   :string(50)
#  closed_at                  :datetime
#  description                :text
#  first_response_at          :datetime
#  last_message_at            :datetime
#  last_message_from_platform :boolean          default(FALSE)
#  message_count              :integer          default(0)
#  priority                   :integer          default("normal"), not null
#  resolved_at                :datetime
#  sla_resolution_breached    :boolean          default(FALSE)
#  sla_resolution_due_at      :datetime
#  sla_response_breached      :boolean          default(FALSE)
#  sla_response_due_at        :datetime
#  sla_warning_sent_at        :datetime
#  status                     :integer          default("open"), not null
#  subject                    :string(255)      not null
#  ticket_number              :string(20)       not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  assigned_to_id             :bigint
#  creator_id                 :bigint           not null
#  website_id                 :bigint           not null
#
# Indexes
#
#  idx_tickets_sla_response_breach_status                  (sla_response_breached,status)
#  index_pwb_support_tickets_on_assigned_to_id             (assigned_to_id)
#  index_pwb_support_tickets_on_assigned_to_id_and_status  (assigned_to_id,status)
#  index_pwb_support_tickets_on_creator_id                 (creator_id)
#  index_pwb_support_tickets_on_priority                   (priority)
#  index_pwb_support_tickets_on_sla_resolution_due_at      (sla_resolution_due_at)
#  index_pwb_support_tickets_on_sla_response_due_at        (sla_response_due_at)
#  index_pwb_support_tickets_on_status                     (status)
#  index_pwb_support_tickets_on_ticket_number              (ticket_number) UNIQUE
#  index_pwb_support_tickets_on_website_id                 (website_id)
#  index_pwb_support_tickets_on_website_id_and_created_at  (website_id,created_at)
#  index_pwb_support_tickets_on_website_id_and_status      (website_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (assigned_to_id => pwb_users.id)
#  fk_rails_...  (creator_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

module Pwb
  RSpec.describe SupportTicket, type: :model do
    let(:website) { create(:pwb_website, subdomain: 'ticket-test') }
    let(:creator) { create(:pwb_user, website: website) }

    before(:each) do
      Pwb::Current.reset
    end

    describe 'factory' do
      it 'has a valid factory' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: creator)
        end
        expect(ticket).to be_valid
      end

      it 'creates ticket with messages trait' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, :with_messages, website: website, creator: creator, message_count: 2)
        end
        # Initial message from description + 2 from trait
        expect(ticket.messages.count).to be >= 2
      end
    end

    describe 'validations' do
      it 'requires a subject' do
        ticket = build(:pwb_support_ticket, website: website, creator: creator, subject: nil)
        expect(ticket).not_to be_valid
        expect(ticket.errors[:subject]).to include("can't be blank")
      end

      it 'requires a creator' do
        ticket = build(:pwb_support_ticket, website: website, creator: nil)
        expect(ticket).not_to be_valid
        expect(ticket.errors[:creator]).to include("must exist")
      end

      it 'validates category inclusion' do
        ticket = build(:pwb_support_ticket, website: website, creator: creator, category: 'invalid')
        expect(ticket).not_to be_valid
        expect(ticket.errors[:category]).to include("is not included in the list")
      end

      it 'allows valid categories' do
        Pwb::SupportTicket::CATEGORIES.each do |category|
          ticket = build(:pwb_support_ticket, website: website, creator: creator, category: category)
          expect(ticket).to be_valid
        end
      end
    end

    describe 'ticket number generation' do
      it 'generates a ticket number on create' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: creator)
        end
        expect(ticket.ticket_number).to be_present
        expect(ticket.ticket_number).to match(/^TKT-[A-Z0-9]{8}$/)
      end

      it 'generates unique ticket numbers' do
        tickets = ActsAsTenant.with_tenant(website) do
          3.times.map { create(:pwb_support_ticket, website: website, creator: creator) }
        end
        ticket_numbers = tickets.map(&:ticket_number)
        expect(ticket_numbers.uniq.length).to eq(3)
      end
    end

    describe 'status enum' do
      it 'defaults to open status' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: creator)
        end
        expect(ticket).to be_status_open
      end

      it 'can be set to in_progress' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, :in_progress, website: website, creator: creator)
        end
        expect(ticket).to be_status_in_progress
      end

      it 'can be set to resolved' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, :resolved, website: website, creator: creator)
        end
        expect(ticket).to be_status_resolved
      end
    end

    describe 'priority enum' do
      it 'defaults to normal priority' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: creator)
        end
        expect(ticket).to be_priority_normal
      end

      it 'can be set to urgent' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, :urgent, website: website, creator: creator)
        end
        expect(ticket).to be_priority_urgent
      end
    end

    describe '#assign_to!' do
      let(:assignee) { create(:pwb_user, website: website) }

      it 'assigns the ticket to a user' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: creator)
        end
        ticket.assign_to!(assignee)
        expect(ticket.assigned_to).to eq(assignee)
        expect(ticket.assigned_at).to be_present
      end

      it 'changes status to in_progress' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: creator)
        end
        ticket.assign_to!(assignee)
        expect(ticket).to be_status_in_progress
      end
    end

    describe '#resolve!' do
      it 'marks the ticket as resolved' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: creator)
        end
        ticket.resolve!
        expect(ticket).to be_status_resolved
        expect(ticket.resolved_at).to be_present
      end
    end

    describe '#close!' do
      it 'marks the ticket as closed' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: creator)
        end
        ticket.close!
        expect(ticket).to be_status_closed
        expect(ticket.closed_at).to be_present
      end
    end

    describe 'needs_response scope' do
      it 'includes tickets where last message is from customer' do
        ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: creator,
                 last_message_from_platform: false, status: :open)
        end
        ActsAsTenant.with_tenant(website) do
          expect(SupportTicket.needs_response).to include(ticket)
        end
      end

      it 'excludes tickets where last message is from platform' do
        ticket = ActsAsTenant.with_tenant(website) do
          t = create(:pwb_support_ticket, website: website, creator: creator, status: :open)
          # Manually set the flag since it's set by callback
          t.update_column(:last_message_from_platform, true)
          t
        end
        expect(SupportTicket.needs_response).not_to include(ticket)
      end
    end

    describe 'scopes' do
      before do
        ActsAsTenant.with_tenant(website) do
          @open_ticket = create(:pwb_support_ticket, website: website, creator: creator, status: :open)
          @in_progress_ticket = create(:pwb_support_ticket, :in_progress, website: website, creator: creator)
          @resolved_ticket = create(:pwb_support_ticket, :resolved, website: website, creator: creator)
          @urgent_ticket = create(:pwb_support_ticket, :urgent, website: website, creator: creator)
        end
      end

      it 'filters by status_open' do
        ActsAsTenant.with_tenant(website) do
          expect(SupportTicket.status_open).to include(@open_ticket, @urgent_ticket)
          expect(SupportTicket.status_open).not_to include(@in_progress_ticket, @resolved_ticket)
        end
      end

      it 'orders by recent' do
        ActsAsTenant.with_tenant(website) do
          tickets = SupportTicket.recent
          expect(tickets.first).to eq(@urgent_ticket)
        end
      end

      it 'filters unassigned tickets' do
        ActsAsTenant.with_tenant(website) do
          expect(SupportTicket.unassigned).to include(@open_ticket, @resolved_ticket, @urgent_ticket)
          expect(SupportTicket.unassigned).not_to include(@in_progress_ticket)
        end
      end
    end

    describe 'website scoping' do
      let(:other_website) { create(:pwb_website, subdomain: 'other-ticket-test') }
      let(:other_creator) { create(:pwb_user, website: other_website) }

      it 'filters tickets by website with for_website scope' do
        our_ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: creator)
        end

        other_ticket = ActsAsTenant.with_tenant(other_website) do
          create(:pwb_support_ticket, website: other_website, creator: other_creator)
        end

        expect(SupportTicket.for_website(website)).to include(our_ticket)
        expect(SupportTicket.for_website(website)).not_to include(other_ticket)
      end

      it 'uses PwbTenant model for auto-scoped queries' do
        # Clear any existing tickets first
        Pwb::SupportTicket.delete_all

        our_ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: creator)
        end

        other_ticket = ActsAsTenant.with_tenant(other_website) do
          create(:pwb_support_ticket, website: other_website, creator: other_creator)
        end

        # PwbTenant::SupportTicket auto-scopes via acts_as_tenant
        ActsAsTenant.with_tenant(website) do
          scoped_ids = PwbTenant::SupportTicket.pluck(:id)
          expect(scoped_ids).to include(our_ticket.id)
          expect(scoped_ids).not_to include(other_ticket.id)
        end
      end
    end
  end
end
