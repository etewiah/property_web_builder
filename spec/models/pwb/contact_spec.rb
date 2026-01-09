# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_contacts
# Database name: primary
#
#  id                   :bigint           not null, primary key
#  details              :json
#  documentation_type   :integer
#  fax                  :string
#  first_name           :string
#  flags                :integer          default(0), not null
#  last_name            :string
#  nationality          :string
#  other_email          :string
#  other_names          :string
#  other_phone_number   :string
#  primary_email        :string
#  primary_phone_number :string
#  title                :integer          default("mr")
#  website_url          :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  documentation_id     :string
#  facebook_id          :string
#  linkedin_id          :string
#  primary_address_id   :integer
#  secondary_address_id :integer
#  skype_id             :string
#  twitter_id           :string
#  user_id              :integer
#  website_id           :bigint
#
# Indexes
#
#  index_pwb_contacts_on_documentation_id          (documentation_id)
#  index_pwb_contacts_on_first_name                (first_name)
#  index_pwb_contacts_on_first_name_and_last_name  (first_name,last_name)
#  index_pwb_contacts_on_last_name                 (last_name)
#  index_pwb_contacts_on_primary_email             (primary_email)
#  index_pwb_contacts_on_primary_phone_number      (primary_phone_number)
#  index_pwb_contacts_on_title                     (title)
#  index_pwb_contacts_on_website_id                (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
require 'rails_helper'

module Pwb
  RSpec.describe Contact, type: :model do
    let(:website) { create(:website) }
    let(:contact) { create(:contact, website: website, first_name: 'John', last_name: 'Doe', primary_email: 'john@example.com') }

    describe 'associations' do
      it { is_expected.to belong_to(:website).class_name('Pwb::Website').optional }
      it { is_expected.to have_many(:messages).class_name('Pwb::Message').dependent(:nullify) }
      it { is_expected.to belong_to(:primary_address).class_name('Pwb::Address').optional }
      it { is_expected.to belong_to(:secondary_address).class_name('Pwb::Address').optional }
      it { is_expected.to belong_to(:user).class_name('Pwb::User').optional }

      # This test specifically catches the instance-dependent scope bug
      # that breaks joins/eager loading
      describe 'messages association with joins' do
        let!(:message) { create(:message, website: website, contact: contact) }

        it 'can be used with joins without raising ArgumentError' do
          expect do
            Contact.joins(:messages).where(id: contact.id).to_a
          end.not_to raise_error
        end

        it 'can be used with includes without raising ArgumentError' do
          expect do
            Contact.includes(:messages).where(id: contact.id).to_a
          end.not_to raise_error
        end

        it 'can be used with eager_load without raising ArgumentError' do
          expect do
            Contact.eager_load(:messages).where(id: contact.id).to_a
          end.not_to raise_error
        end
      end
    end

    describe 'scopes' do
      describe '.with_messages' do
        let!(:contact_with_messages) { create(:contact, website: website) }
        let!(:contact_without_messages) { create(:contact, website: website) }
        let!(:message) { create(:message, website: website, contact: contact_with_messages) }

        it 'returns only contacts that have messages' do
          result = Contact.with_messages
          expect(result).to include(contact_with_messages)
          expect(result).not_to include(contact_without_messages)
        end
      end

      describe '.ordered_by_recent_message' do
        let!(:old_contact) { create(:contact, website: website) }
        let!(:new_contact) { create(:contact, website: website) }
        let!(:old_message) { create(:message, website: website, contact: old_contact, created_at: 2.days.ago) }
        let!(:new_message) { create(:message, website: website, contact: new_contact, created_at: 1.hour.ago) }

        it 'orders contacts by most recent message first' do
          result = Contact.ordered_by_recent_message
          expect(result.first).to eq(new_contact)
          expect(result.last).to eq(old_contact)
        end
      end
    end

    describe '#display_name' do
      it 'returns full name when both first and last name present' do
        contact = build(:contact, first_name: 'John', last_name: 'Doe')
        expect(contact.display_name).to eq('John Doe')
      end

      it 'returns first name only when last name is blank' do
        contact = build(:contact, first_name: 'John', last_name: nil)
        expect(contact.display_name).to eq('John')
      end

      it 'returns email prefix when name is blank' do
        contact = build(:contact, first_name: nil, last_name: nil, primary_email: 'john@example.com')
        expect(contact.display_name).to eq('john')
      end

      it 'returns Unknown Contact when all fields are blank' do
        contact = build(:contact, first_name: nil, last_name: nil, primary_email: nil)
        expect(contact.display_name).to eq('Unknown Contact')
      end
    end

    describe '#unread_messages_count' do
      let!(:unread1) { create(:message, website: website, contact: contact, read: false) }
      let!(:unread2) { create(:message, website: website, contact: contact, read: false) }
      let!(:read_msg) { create(:message, website: website, contact: contact, read: true) }

      it 'returns count of unread messages' do
        expect(contact.unread_messages_count).to eq(2)
      end

      context 'with messages from another website' do
        let(:other_website) { create(:website) }
        let!(:other_message) { create(:message, website: other_website, contact: contact, read: false) }

        it 'only counts messages from same website' do
          expect(contact.unread_messages_count).to eq(2)
        end
      end
    end

    describe '#last_message' do
      let!(:old_message) { create(:message, website: website, contact: contact, created_at: 2.days.ago, content: 'Old') }
      let!(:new_message) { create(:message, website: website, contact: contact, created_at: 1.hour.ago, content: 'New') }

      it 'returns the most recent message' do
        expect(contact.last_message).to eq(new_message)
      end

      context 'with messages from another website' do
        let(:other_website) { create(:website) }
        let!(:newer_other_message) { create(:message, website: other_website, contact: contact, created_at: 1.minute.ago, content: 'Other tenant') }

        it 'only considers messages from same website' do
          expect(contact.last_message).to eq(new_message)
          expect(contact.last_message.content).to eq('New')
        end
      end
    end

    describe 'enums' do
      it { is_expected.to define_enum_for(:title).with_values(mr: 0, mrs: 1) }
    end
  end
end
