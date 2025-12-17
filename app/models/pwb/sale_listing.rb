# frozen_string_literal: true

module Pwb
  # SaleListing represents a sale transaction for a property.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::SaleListing for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  class SaleListing < ApplicationRecord
    include NtfyListingNotifications
    include ListingStateable
    extend Mobility

    self.table_name = 'pwb_sale_listings'
    belongs_to :realty_asset, class_name: 'Pwb::RealtyAsset'
    monetize :price_sale_current_cents, with_model_currency: :price_sale_current_currency
    monetize :commission_cents, with_model_currency: :commission_currency

    # Mobility translations for listing marketing text
    # locale_accessors configured globally provides title_en, title_es, etc.
    translates :title, :description

    # Delegate common attributes to realty_asset for convenience
    delegate :reference, :website, :website_id,
             :count_bedrooms, :count_bathrooms, :street_address, :city,
             :prop_photos, :features, to: :realty_asset, allow_nil: true

    private

    # Required by ListingStateable
    def listings_of_same_type
      realty_asset&.sale_listings || self.class.none
    end
  end
end
