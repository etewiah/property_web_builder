# frozen_string_literal: true

module PwbTenant
  class Agency < ApplicationRecord
    belongs_to :primary_address, optional: true, class_name: 'Pwb::Address', foreign_key: 'primary_address_id'
    belongs_to :secondary_address, optional: true, class_name: 'Pwb::Address', foreign_key: 'secondary_address_id'

    def as_json(options = nil)
      super({
        only: %w[
          display_name company_name
          phone_number_primary phone_number_mobile phone_number_other
          email_primary email_for_property_contact_form email_for_general_contact_form
        ]
      }.merge(options || {}))
    end

    delegate :street_number, :street_address, :city, :postal_code,
             to: :primary_address, allow_nil: true

    def show_contact_map
      primary_address.present?
    end
  end
end
