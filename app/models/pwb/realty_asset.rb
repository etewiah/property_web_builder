module Pwb
  class RealtyAsset < ApplicationRecord
    self.table_name = 'pwb_realty_assets'
    has_many :sale_listings, class_name: 'Pwb::SaleListing', foreign_key: 'realty_asset_id', dependent: :destroy
    has_many :rental_listings, class_name: 'Pwb::RentalListing', foreign_key: 'realty_asset_id', dependent: :destroy
    
    has_many :prop_photos, class_name: 'Pwb::PropPhoto', foreign_key: 'realty_asset_id', dependent: :destroy
    has_many :features, class_name: 'Pwb::Feature', foreign_key: 'realty_asset_id', dependent: :destroy
    has_many :translations, class_name: 'Pwb::Prop::Translation', foreign_key: 'realty_asset_id', dependent: :destroy
    
    belongs_to :website, class_name: 'Pwb::Website'
    
    # Helpers for View Compatibility
    def bedrooms
      count_bedrooms
    end
    
    def bathrooms
      count_bathrooms
    end
    
    def surface_area
      constructed_area
    end
    
    def location
      [street_address, city, postal_code, country].compact.reject(&:empty?).join(", ")
    end
    
    def price
      # Return sale price if available, else rental price, else nil
      if sale_listings.visible.any?
        sale_listings.visible.first.price_sale_current.format(no_cents: true)
      elsif rental_listings.visible.any?
        rental_listings.visible.first.price_rental_monthly_current.format(no_cents: true)
      else
        nil
      end
    end
  end
end
