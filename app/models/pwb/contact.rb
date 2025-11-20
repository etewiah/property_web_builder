module Pwb
  class Contact < ApplicationRecord
    has_many :messages
    belongs_to :primary_address, optional: true, class_name: "Address", foreign_key: 'primary_address_id'
    belongs_to :secondary_address, optional: true, class_name: "Address", foreign_key: 'secondary_address_id'
    belongs_to :user, optional: true

    # enum title: [ :mr, :mrs ]
    # above method of declaring less flexible than below:
    enum :title, { mr: 0, mrs: 1 }

    def street_number
      primary_address.present? ? primary_address.street_number : nil
    end

    def street_address
      primary_address.present? ? primary_address.street_address : nil
    end

    def city
      primary_address.present? ? primary_address.city : nil
    end

    def postal_code
      primary_address.present? ? primary_address.postal_code : nil
    end
  end
end
