# frozen_string_literal: true

module PwbTenant
  class Contact < ApplicationRecord
    # Associations
    has_many :messages, class_name: 'PwbTenant::Message'
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
