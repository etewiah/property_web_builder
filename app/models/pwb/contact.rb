# frozen_string_literal: true

module Pwb
  # Contact represents a person or entity that interacts with the website.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::Contact for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
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
