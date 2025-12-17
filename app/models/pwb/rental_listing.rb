# frozen_string_literal: true

module Pwb
  # RentalListing represents a rental transaction for a property.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::RentalListing for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  class RentalListing < ApplicationRecord
    include NtfyListingNotifications
    include ListingStateable
    extend Mobility

    self.table_name = 'pwb_rental_listings'
    belongs_to :realty_asset, class_name: 'Pwb::RealtyAsset'
    monetize :price_rental_monthly_current_cents, with_model_currency: :price_rental_monthly_current_currency
    monetize :price_rental_monthly_low_season_cents, with_model_currency: :price_rental_monthly_current_currency
    monetize :price_rental_monthly_high_season_cents, with_model_currency: :price_rental_monthly_current_currency

    # Mobility translations for listing marketing text
    # locale_accessors configured globally provides title_en, title_es, etc.
    translates :title, :description

    # Rental-specific scopes
    scope :for_rent_short_term, -> { where(for_rent_short_term: true) }
    scope :for_rent_long_term, -> { where(for_rent_long_term: true) }

    # Delegate common attributes to realty_asset for convenience
    delegate :reference, :website, :website_id,
             :count_bedrooms, :count_bathrooms, :street_address, :city,
             :prop_photos, :features, to: :realty_asset, allow_nil: true

    # Convenience method to check if this is a vacation rental
    def vacation_rental?
      for_rent_short_term?
    end

    private

    # Required by ListingStateable
    def listings_of_same_type
      realty_asset&.rental_listings || self.class.none
    end
  end
end
