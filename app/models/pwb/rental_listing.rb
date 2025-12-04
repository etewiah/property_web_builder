module Pwb
  class RentalListing < ApplicationRecord
    extend Mobility

    self.table_name = 'pwb_rental_listings'
    belongs_to :realty_asset, class_name: 'Pwb::RealtyAsset'
    monetize :price_rental_monthly_current_cents, with_model_currency: :price_rental_monthly_current_currency
    monetize :price_rental_monthly_low_season_cents, with_model_currency: :price_rental_monthly_current_currency
    monetize :price_rental_monthly_high_season_cents, with_model_currency: :price_rental_monthly_current_currency

    # Mobility translations for listing marketing text
    # locale_accessors configured globally provides title_en, title_es, etc.
    translates :title, :description

    scope :visible, -> { where(visible: true) }
    scope :highlighted, -> { where(highlighted: true) }
    scope :archived, -> { where(archived: true) }
    scope :for_rent_short_term, -> { where(for_rent_short_term: true) }
    scope :for_rent_long_term, -> { where(for_rent_long_term: true) }
    scope :active, -> { where(visible: true, archived: false) }

    # Refresh the materialized view after changes
    after_commit :refresh_properties_view

    # Delegate common attributes to realty_asset for convenience
    delegate :reference, :website, :website_id,
             :count_bedrooms, :count_bathrooms, :street_address, :city,
             :prop_photos, :features, to: :realty_asset, allow_nil: true

    # Convenience method to check if this is a vacation rental
    def vacation_rental?
      for_rent_short_term?
    end

    private

    def refresh_properties_view
      Pwb::Property.refresh
    rescue StandardError => e
      Rails.logger.warn "Failed to refresh properties view: #{e.message}"
    end
  end
end
