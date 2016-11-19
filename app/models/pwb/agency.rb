module Pwb
  class Agency < ApplicationRecord
    # has_many :users

    # foreign_key of primary_address_id is col here on agency
    # belongs_to :primary_address, :class_name => "MasterAddress", :foreign_key => 'primary_address_id'
    # belongs_to :secondary_address, :class_name => "MasterAddress", :foreign_key => 'secondary_address_id'

    # def show_contact_map
    #   return self.primary_address.present?
    # end
  end
end
