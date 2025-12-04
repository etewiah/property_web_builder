module Pwb
  class SaleListing < ApplicationRecord
    self.table_name = 'pwb_sale_listings'
    belongs_to :realty_asset, class_name: 'Pwb::RealtyAsset'
    monetize :price_sale_current_cents, with_model_currency: :price_sale_current_currency
    
    scope :visible, -> { where(visible: true) }
    scope :highlighted, -> { where(highlighted: true) }
    scope :archived, -> { where(archived: true) }
  end
end
