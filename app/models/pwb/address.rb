module Pwb
  class Address < ApplicationRecord
    has_one :agency, foreign_key: "primary_address_id", class_name: "Agency"
    has_one :agency_as_secondary, foreign_key: "secondary_address_id", class_name: "Agency"
  end
end
