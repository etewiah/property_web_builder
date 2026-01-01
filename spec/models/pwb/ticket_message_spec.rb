# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_ticket_messages
#
#  id                  :uuid             not null, primary key
#  content             :text             not null
#  from_platform_admin :boolean          default(FALSE)
#  internal_note       :boolean          default(FALSE)
#  status_changed_from :string(50)
#  status_changed_to   :string(50)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  support_ticket_id   :uuid             not null
#  user_id             :bigint           not null
#  website_id          :bigint           not null
#
# Indexes
#
#  index_pwb_ticket_messages_on_support_ticket_id                 (support_ticket_id)
#  index_pwb_ticket_messages_on_support_ticket_id_and_created_at  (support_ticket_id,created_at)
#  index_pwb_ticket_messages_on_user_id                           (user_id)
#  index_pwb_ticket_messages_on_website_id                        (website_id)
#  index_pwb_ticket_messages_on_website_id_and_created_at         (website_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (support_ticket_id => pwb_support_tickets.id)
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

module Pwb
  RSpec.describe TicketMessage, type: :model do
    let(:website) { create(:pwb_website, subdomain: 'ticket-msg-test') }
    let(:creator) { create(:pwb_user, website: website) }
    let(:ticket) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_support_ticket, website: website, creator: creator)
      end
    end

    before(:each) do
      Pwb::Current.reset
    end

    describe 'factory' do
      it 'has a valid factory' do
        message = ActsAsTenant.with_tenant(website) do
          create(:pwb_ticket_message, support_ticket: ticket, website: website, user: creator)
        end
        expect(message).to be_valid
      end

      it 'creates internal note with trait' do
        message = ActsAsTenant.with_tenant(website) do
          create(:pwb_ticket_message, :internal_note, support_ticket: ticket, website: website, user: creator)
        end
        expect(message.internal_note).to be true
        expect(message.from_platform_admin).to be true
      end
    end

    describe 'validations' do
      it 'requires content' do
        message = build(:pwb_ticket_message, support_ticket: ticket, website: website, user: creator, content: nil)
        expect(message).not_to be_valid
        expect(message.errors[:content]).to include("can't be blank")
      end

      it 'requires a user' do
        message = build(:pwb_ticket_message, support_ticket: ticket, website: website, user: nil)
        expect(message).not_to be_valid
        expect(message.errors[:user]).to include("must exist")
      end
    end

    describe 'scopes' do
      before do
        ActsAsTenant.with_tenant(website) do
          @public_message = create(:pwb_ticket_message, support_ticket: ticket, website: website, user: creator)
          @internal_message = create(:pwb_ticket_message, :internal_note, support_ticket: ticket, website: website, user: creator)
          @platform_message = create(:pwb_ticket_message, :from_platform, support_ticket: ticket, website: website, user: creator)
        end
      end

      it 'filters public_messages' do
        ActsAsTenant.with_tenant(website) do
          expect(TicketMessage.public_messages).to include(@public_message, @platform_message)
          expect(TicketMessage.public_messages).not_to include(@internal_message)
        end
      end

      it 'orders chronologically' do
        ActsAsTenant.with_tenant(website) do
          messages = ticket.messages.chronological
          # First message is the initial description, last is platform message
          expect(messages.last).to eq(@platform_message)
        end
      end
    end

    describe 'counter cache' do
      it 'updates ticket message_count on create' do
        # Ticket starts with 1 message from initial description
        ticket.reload
        initial_count = ticket.message_count

        ActsAsTenant.with_tenant(website) do
          create(:pwb_ticket_message, support_ticket: ticket, website: website, user: creator)
        end

        # The callback updates the count via support_ticket.messages.count
        expect(ticket.reload.message_count).to be > initial_count
      end
    end

    describe '#author_name' do
      it 'returns user display name' do
        creator.update(first_names: 'John', last_names: 'Doe')
        message = ActsAsTenant.with_tenant(website) do
          create(:pwb_ticket_message, support_ticket: ticket, website: website, user: creator)
        end
        expect(message.author_name).to include('John')
      end
    end

    describe 'website scoping' do
      let(:other_website) { create(:pwb_website, subdomain: 'other-msg-test') }
      let(:other_creator) { create(:pwb_user, website: other_website) }
      let(:other_ticket) do
        ActsAsTenant.with_tenant(other_website) do
          create(:pwb_support_ticket, website: other_website, creator: other_creator)
        end
      end

      it 'filters messages by website with for_website scope' do
        our_message = ActsAsTenant.with_tenant(website) do
          create(:pwb_ticket_message, support_ticket: ticket, website: website, user: creator)
        end

        other_message = ActsAsTenant.with_tenant(other_website) do
          create(:pwb_ticket_message, support_ticket: other_ticket, website: other_website, user: other_creator)
        end

        expect(TicketMessage.for_website(website)).to include(our_message)
        expect(TicketMessage.for_website(website)).not_to include(other_message)
      end

      it 'uses PwbTenant model for auto-scoped queries' do
        # Clear existing messages
        Pwb::TicketMessage.delete_all
        Pwb::SupportTicket.delete_all

        # Recreate tickets after clearing
        new_ticket = ActsAsTenant.with_tenant(website) do
          create(:pwb_support_ticket, website: website, creator: creator)
        end

        new_other_ticket = ActsAsTenant.with_tenant(other_website) do
          create(:pwb_support_ticket, website: other_website, creator: other_creator)
        end

        our_message = ActsAsTenant.with_tenant(website) do
          create(:pwb_ticket_message, support_ticket: new_ticket, website: website, user: creator)
        end

        other_message = ActsAsTenant.with_tenant(other_website) do
          create(:pwb_ticket_message, support_ticket: new_other_ticket, website: other_website, user: other_creator)
        end

        # PwbTenant::TicketMessage auto-scopes via acts_as_tenant
        ActsAsTenant.with_tenant(website) do
          scoped_ids = PwbTenant::TicketMessage.pluck(:id)
          expect(scoped_ids).to include(our_message.id)
          expect(scoped_ids).not_to include(other_message.id)
        end
      end
    end
  end
end
