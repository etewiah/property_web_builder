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
  #
  class Contact < ApplicationRecord
    self.table_name = 'pwb_contacts'

    belongs_to :website, class_name: 'Pwb::Website', optional: true

    # Associations
    has_many :messages, class_name: 'Pwb::Message'
    belongs_to :primary_address, optional: true, class_name: 'Pwb::Address', foreign_key: 'primary_address_id'
    belongs_to :secondary_address, optional: true, class_name: 'Pwb::Address', foreign_key: 'secondary_address_id'
    belongs_to :user, optional: true, class_name: 'Pwb::User'

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
  end
end
