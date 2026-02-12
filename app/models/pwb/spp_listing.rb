# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_spp_listings
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  active               :boolean          default(FALSE), not null
#  archived             :boolean          default(FALSE)
#  extra_data           :jsonb
#  highlighted_features :jsonb
#  listing_type         :string           default("sale"), not null
#  live_url             :string
#  noindex              :boolean          default(FALSE), not null
#  photo_ids_ordered    :jsonb
#  price_cents          :bigint           default(0), not null
#  price_currency       :string           default("EUR"), not null
#  published_at         :datetime
#  spp_settings         :jsonb
#  spp_slug             :string
#  template             :string
#  translations         :jsonb            not null
#  visible              :boolean          default(FALSE)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  realty_asset_id      :uuid             not null
#
# Indexes
#
#  index_pwb_spp_listings_on_noindex          (noindex)
#  index_pwb_spp_listings_on_realty_asset_id  (realty_asset_id)
#  index_pwb_spp_listings_on_spp_slug         (spp_slug)
#  index_pwb_spp_listings_on_translations     (translations) USING gin
#  index_pwb_spp_listings_unique_active       (realty_asset_id,listing_type,active) UNIQUE WHERE (active = true)
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#
module Pwb
  class SppListing < ApplicationRecord
    include NtfyListingNotifications
    include ListingStateable
    include SeoValidatable
    include RefreshesPropertiesView
    extend Mobility

    self.table_name = 'pwb_spp_listings'

    LISTING_TYPES = %w[sale rental].freeze

    belongs_to :realty_asset, class_name: 'Pwb::RealtyAsset'

    # Mobility translations for listing marketing text
    translates :title, :description, :seo_title, :meta_description

    # Delegate physical property attributes from realty_asset
    delegate :reference, :website, :website_id,
             :count_bedrooms, :count_bathrooms, :street_address, :city,
             :latitude, :longitude, :slug,
             to: :realty_asset, allow_nil: true

    monetize :price_cents, with_model_currency: :price_currency

    validates :realty_asset_id, presence: true
    validates :listing_type, presence: true, inclusion: { in: LISTING_TYPES }

    scope :sale, -> { where(listing_type: 'sale') }
    scope :rental, -> { where(listing_type: 'rental') }

    # Curated photo list — returns PropPhotos in the order specified by this listing.
    # Falls back to the property's default photo order if no curation is set.
    def ordered_photos
      if photo_ids_ordered.present?
        photos_by_id = realty_asset.prop_photos.index_by(&:id)
        photo_ids_ordered.filter_map { |id| photos_by_id[id] }
      else
        realty_asset.prop_photos
      end
    end

    # Curated feature list — returns only the highlighted features for this listing.
    # Falls back to all property features if no highlights are set.
    def display_features
      if highlighted_features.present?
        realty_asset.features.where(feature_key: highlighted_features)
      else
        realty_asset.features
      end
    end

    private

    # Required by ListingStateable — scoped to same listing_type
    def listings_of_same_type
      realty_asset&.spp_listings&.where(listing_type: listing_type) || self.class.none
    end
  end
end
