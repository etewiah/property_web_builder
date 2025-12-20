# frozen_string_literal: true

module Pwb
  # SaleListing represents a sale transaction for a property.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::SaleListing for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
# == Schema Information
#
# Table name: pwb_sale_listings
#
#  id                          :uuid             not null, primary key
#  active                      :boolean          default(FALSE), not null
#  archived                    :boolean          default(FALSE)
#  commission_cents            :bigint           default(0)
#  commission_currency         :string           default("EUR")
#  furnished                   :boolean          default(FALSE)
#  highlighted                 :boolean          default(FALSE)
#  noindex                     :boolean          default(FALSE), not null
#  price_sale_current_cents    :bigint           default(0)
#  price_sale_current_currency :string           default("EUR")
#  reference                   :string
#  reserved                    :boolean          default(FALSE)
#  translations                :jsonb            not null
#  visible                     :boolean          default(FALSE)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  realty_asset_id             :uuid
#
# Indexes
#
#  index_pwb_sale_listings_on_noindex          (noindex)
#  index_pwb_sale_listings_on_realty_asset_id  (realty_asset_id)
#  index_pwb_sale_listings_on_translations     (translations) USING gin
#  index_pwb_sale_listings_unique_active       (realty_asset_id,active) UNIQUE WHERE (active = true)
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#
  class SaleListing < ApplicationRecord
    include NtfyListingNotifications
    include ListingStateable
    include SeoValidatable
    extend Mobility

    self.table_name = 'pwb_sale_listings'
    belongs_to :realty_asset, class_name: 'Pwb::RealtyAsset'
    monetize :price_sale_current_cents, with_model_currency: :price_sale_current_currency
    monetize :commission_cents, with_model_currency: :commission_currency

    # Mobility translations for listing marketing text
    # locale_accessors configured globally provides title_en, title_es, etc.
    # SEO fields allow custom meta tags per locale
    translates :title, :description, :seo_title, :meta_description

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
