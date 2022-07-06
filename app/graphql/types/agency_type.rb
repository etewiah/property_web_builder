# frozen_string_literal: true

module Types
  class AgencyType < Types::BaseObject
    field :display_name, String, null: true
    field :email_primary, String, null: true
    field :email_for_property_contact_form, String, null: true
    field :email_for_general_contact_form, String, null: true
    field :phone_number_primary, String, null: true
  end
end
