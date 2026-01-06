# == Schema Information
#
# Table name: pwb_addresses
# Database name: primary
#
#  id             :integer          not null, primary key
#  city           :string
#  country        :string
#  latitude       :float
#  longitude      :float
#  postal_code    :string
#  region         :string
#  street_address :string
#  street_number  :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
module Pwb
  class Address < ApplicationRecord
    has_one :agency, foreign_key: 'primary_address_id', class_name: 'PwbTenant::Agency'
    has_one :agency_as_secondary, foreign_key: 'secondary_address_id', class_name: 'PwbTenant::Agency'
  end
end
