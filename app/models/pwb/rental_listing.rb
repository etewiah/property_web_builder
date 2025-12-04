module Pwb
  class RentalListing < ApplicationRecord
    self.table_name = 'pwb_rental_listings'
    belongs_to :realty_asset, class_name: 'Pwb::RealtyAsset'
    monetize :price_rental_monthly_current_cents, with_model_currency: :price_rental_monthly_current_currency
    
    scope :visible, -> { where(visible: true) }
    scope :highlighted, -> { where(highlighted: true) }
    scope :archived, -> { where(archived: true) }
    scope :for_rent_short_term, -> { where(for_rent_short_term: true) }
    scope :for_rent_long_term, -> { where(for_rent_long_term: true) }
  end
end
