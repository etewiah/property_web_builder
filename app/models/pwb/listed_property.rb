# frozen_string_literal: true

module Pwb
  # ListedProperty is a read-only model backed by a materialized view.
  # It denormalizes pwb_realty_assets + pwb_sale_listings + pwb_rental_listings
  # into a single queryable interface optimized for property search and display.
  #
  # For writes, use the underlying models:
  #   - Pwb::RealtyAsset (physical property data)
  #   - Pwb::SaleListing (sale transaction data)
  #   - Pwb::RentalListing (rental transaction data)
  #
  # After writes, call Pwb::ListedProperty.refresh to update the materialized view.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::ListedProperty for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
# == Schema Information
#
# Table name: pwb_properties
#
#  id                                     :uuid             primary key
#  city                                   :string
#  commission_cents                       :bigint
#  commission_currency                    :string
#  constructed_area                       :float
#  count_bathrooms                        :float
#  count_bedrooms                         :integer
#  count_garages                          :integer
#  count_toilets                          :integer
#  country                                :string
#  currency                               :string
#  energy_performance                     :float
#  energy_rating                          :integer
#  for_rent                               :boolean
#  for_rent_long_term                     :boolean
#  for_rent_short_term                    :boolean
#  for_sale                               :boolean
#  furnished                              :boolean
#  highlighted                            :boolean
#  latitude                               :float
#  longitude                              :float
#  plot_area                              :float
#  postal_code                            :string
#  price_rental_monthly_current_cents     :bigint
#  price_rental_monthly_current_currency  :string
#  price_rental_monthly_for_search_cents  :bigint
#  price_rental_monthly_high_season_cents :bigint
#  price_rental_monthly_low_season_cents  :bigint
#  price_sale_current_cents               :bigint
#  price_sale_current_currency            :string
#  prop_origin_key                        :string
#  prop_state_key                         :string
#  prop_type_key                          :string
#  reference                              :string
#  region                                 :string
#  rental_furnished                       :boolean
#  rental_highlighted                     :boolean
#  rental_reserved                        :boolean
#  reserved                               :boolean
#  sale_furnished                         :boolean
#  sale_highlighted                       :boolean
#  sale_reserved                          :boolean
#  slug                                   :string
#  street_address                         :string
#  street_name                            :string
#  street_number                          :string
#  visible                                :boolean
#  year_construction                      :integer
#  created_at                             :datetime
#  updated_at                             :datetime
#  rental_listing_id                      :uuid
#  sale_listing_id                        :uuid
#  website_id                             :integer
#
# Indexes
#
#  index_pwb_properties_on_bathrooms           (count_bathrooms)
#  index_pwb_properties_on_bedrooms            (count_bedrooms)
#  index_pwb_properties_on_for_rent            (for_rent)
#  index_pwb_properties_on_for_sale            (for_sale)
#  index_pwb_properties_on_highlighted         (highlighted)
#  index_pwb_properties_on_id                  (id) UNIQUE
#  index_pwb_properties_on_lat_lng             (latitude,longitude)
#  index_pwb_properties_on_price_rental_cents  (price_rental_monthly_current_cents)
#  index_pwb_properties_on_price_sale_cents    (price_sale_current_cents)
#  index_pwb_properties_on_prop_type           (prop_type_key)
#  index_pwb_properties_on_reference           (reference)
#  index_pwb_properties_on_slug                (slug)
#  index_pwb_properties_on_visible             (visible)
#  index_pwb_properties_on_website_id          (website_id)
#
  class ListedProperty < ApplicationRecord
    # Concerns - extracted for better organization and reusability
    include ::ListedProperty::Pricing
    include ::ListedProperty::Searchable
    include ::ListedProperty::UrlHelpers
    include ::ListedProperty::PhotoAccessors
    include ::ListedProperty::Localizable

    self.table_name = 'pwb_properties'
    self.primary_key = 'id'

    # ============================================
    # Associations (read-only, via the realty_asset_id)
    # ============================================

    belongs_to :website, class_name: 'Pwb::Website', optional: true

    has_many :prop_photos,
             -> { order(:sort_order) },
             class_name: 'Pwb::PropPhoto',
             foreign_key: 'realty_asset_id',
             primary_key: 'id'

    has_many :features,
             class_name: 'PwbTenant::Feature',
             foreign_key: 'realty_asset_id',
             primary_key: 'id'

    # ============================================
    # Underlying Models (for write operations)
    # ============================================

    def realty_asset
      Pwb::RealtyAsset.find(id)
    end

    def sale_listing
      Pwb::SaleListing.find_by(id: sale_listing_id) if sale_listing_id.present?
    end

    def rental_listing
      Pwb::RentalListing.find_by(id: rental_listing_id) if rental_listing_id.present?
    end

    # ============================================
    # Read-Only Protection
    # ============================================

    def readonly?
      true
    end

    # ============================================
    # Materialized View Refresh
    # ============================================

    # Refresh the materialized view (use after creating/updating properties)
    # @param concurrently [Boolean] if true, allows reads during refresh (requires unique index)
    def self.refresh(concurrently: true)
      Scenic.database.refresh_materialized_view(table_name, concurrently: concurrently, cascade: false)
    end

    # Async refresh (if Sidekiq or similar is available)
    def self.refresh_async
      if defined?(RefreshPropertiesViewJob)
        RefreshPropertiesViewJob.perform_later
      else
        refresh
      end
    end

    # ============================================
    # Compatibility Methods (from Pwb::Prop)
    # ============================================

    def bedrooms
      count_bedrooms
    end

    def bathrooms
      count_bathrooms
    end

    def surface_area
      constructed_area
    end

    def area_unit
      website&.default_area_unit || "sqmt"
    end

    def location
      [street_address, city, postal_code, country].compact.reject(&:blank?).join(", ")
    end

    def geocodeable_address
      [street_address, city, region, postal_code].compact.reject(&:blank?).join(", ")
    end

    def has_garage
      count_garages && count_garages > 0
    end

    # ============================================
    # Map Methods
    # ============================================

    def show_map
      latitude.present? && longitude.present?
    end

    def hide_map
      false # Could add to view if needed
    end

    def obscure_map
      false # Could add to view if needed
    end

    # ============================================
    # Feature Methods
    # ============================================

    def get_features
      Hash[features.map { |f| [f.feature_key, true] }]
    end

    def extras_for_display
      get_features.keys.map { |extra| I18n.t(extra) }.sort_by(&:downcase)
    end

    # ============================================
    # JSON Serialization
    # ============================================

    def as_json(options = nil)
      super(options).tap do |hash|
        hash['prop_photos'] = prop_photos.map do |photo|
          if photo.image.attached?
            { 'image' => Rails.application.routes.url_helpers.rails_blob_path(photo.image, only_path: true) }
          else
            { 'image' => nil }
          end
        end
        hash['title'] = title
        hash['description'] = description
      end
    end
  end
end
