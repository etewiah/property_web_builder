# frozen_string_literal: true

module Pwb
  # Contact represents a person or entity that interacts with the website.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::Contact for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
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
  class Contact < ApplicationRecord
    self.table_name = 'pwb_contacts'

    belongs_to :website, class_name: 'Pwb::Website', optional: true

    # Associations
    # NOTE: Tenant scoping for messages is handled at the query level in controllers
    # to avoid instance-dependent scope limitations with joins/eager loading.
    # Always filter by website_id when querying messages through this association.
    has_many :messages,
             class_name: 'Pwb::Message',
             foreign_key: :contact_id,
             inverse_of: :contact,
             dependent: :nullify

    belongs_to :primary_address, optional: true, class_name: 'Pwb::Address', foreign_key: 'primary_address_id'
    belongs_to :secondary_address, optional: true, class_name: 'Pwb::Address', foreign_key: 'secondary_address_id'
    belongs_to :user, optional: true, class_name: 'Pwb::User'

    # Scopes
    # Use exists subquery instead of DISTINCT to avoid PostgreSQL JSON column comparison issues
    scope :with_messages, -> {
      where('EXISTS (SELECT 1 FROM pwb_messages WHERE pwb_messages.contact_id = pwb_contacts.id)')
    }
    scope :ordered_by_recent_message, -> {
      joins(:messages)
        .select('pwb_contacts.*, MAX(pwb_messages.created_at) as last_message_at')
        .group('pwb_contacts.id')
        .order('last_message_at DESC')
    }

    # Enums
    enum :title, { mr: 0, mrs: 1 }

    # Delegate address methods
    def street_number
      primary_address&.street_number
    end

    def street_address
      primary_address&.street_address
    end

    def city
      primary_address&.city
    end

    def postal_code
      primary_address&.postal_code
    end

    # Display name for inbox/CRM views
    def display_name
      name = [first_name, last_name].compact.join(' ')
      name.presence || primary_email&.split('@')&.first || 'Unknown Contact'
    end

    # Count of unread messages for this contact (scoped to same website)
    def unread_messages_count
      messages.where(website_id: website_id, read: false).count
    end

    # Most recent message from this contact (scoped to same website)
    def last_message
      messages.where(website_id: website_id).order(created_at: :desc).first
    end
  end
end
