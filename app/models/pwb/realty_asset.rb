module Pwb
  # RealtyAsset represents a physical property (the building/land itself).
  # This is the "source of truth" for property data in the normalized schema.
  #
  # Transaction data is stored in:
  #   - SaleListing (for properties being sold)
  #   - RentalListing (for properties being rented)
  #
  # For read operations, use Pwb::ListedProperty (materialized view) instead,
  # which provides a denormalized, query-optimized view of all data.
  #
  class RealtyAsset < ApplicationRecord
    self.table_name = 'pwb_realty_assets'

    # Associations
    has_many :sale_listings, class_name: 'Pwb::SaleListing', foreign_key: 'realty_asset_id', dependent: :destroy
    has_many :rental_listings, class_name: 'Pwb::RentalListing', foreign_key: 'realty_asset_id', dependent: :destroy
    has_many :prop_photos, -> { order "sort_order asc" }, class_name: 'Pwb::PropPhoto', foreign_key: 'realty_asset_id', dependent: :destroy
    has_many :features, class_name: 'Pwb::Feature', foreign_key: 'realty_asset_id', dependent: :destroy
    # Note: Translations are now stored in pwb_props.translations JSONB column via Mobility
    # Access via the associated prop model

    belongs_to :website, class_name: 'Pwb::Website', optional: true

    # Geocoding
    geocoded_by :geocodeable_address do |obj, results|
      if geo = results.first
        obj.longitude = geo.longitude
        obj.latitude = geo.latitude
        obj.city = geo.city
        obj.street_number = geo.street_number
        obj.street_address = geo.street_address
        obj.postal_code = geo.postal_code
        obj.region = geo.state
        obj.country = geo.country
      end
    end

    # Refresh the materialized view after changes
    after_commit :refresh_properties_view

    # ============================================
    # View Compatibility Helpers
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

    def location
      [street_address, city, postal_code, country].compact.reject(&:blank?).join(", ")
    end

    def geocodeable_address
      [street_address, city, region, postal_code].compact.reject(&:blank?).join(", ")
    end

    def price
      if sale_listings.visible.any?
        sale_listings.visible.first.price_sale_current.format(no_cents: true)
      elsif rental_listings.visible.any?
        rental_listings.visible.first.price_rental_monthly_current.format(no_cents: true)
      end
    end

    # ============================================
    # Listing Status
    # ============================================

    def for_sale?
      sale_listings.active.exists?
    end

    def for_rent?
      rental_listings.active.exists?
    end

    def visible?
      for_sale? || for_rent?
    end

    # Get the active sale listing (only one can be active at a time)
    def active_sale_listing
      sale_listings.active_listing.first
    end

    # Get the active rental listing (only one can be active at a time)
    def active_rental_listing
      rental_listings.active_listing.first
    end

    # ============================================
    # Title/Description
    # ============================================
    # Note: RealtyAsset represents the physical property, not the listing.
    # Title and description are marketing text that belong to the listing
    # (SaleListing or RentalListing), not the underlying asset.
    # These methods return nil; use listing.title/description instead.

    def title
      nil
    end

    def description
      nil
    end

    # ============================================
    # Feature Methods
    # ============================================

    def get_features
      Hash[features.map { |f| [f.feature_key, true] }]
    end

    def set_features=(features_json)
      return unless features_json.is_a?(Hash)
      features_json.each do |feature_key, value|
        if value == "true" || value == true
          features.find_or_create_by(feature_key: feature_key)
        else
          features.where(feature_key: feature_key).delete_all
        end
      end
    end

    # ============================================
    # Photo Methods
    # ============================================

    def ordered_photo(number)
      prop_photos[number - 1] if prop_photos.length >= number
    end

    def primary_image_url
      if prop_photos.any? && ordered_photo(1)&.image&.attached?
        Rails.application.routes.url_helpers.rails_blob_path(ordered_photo(1).image, only_path: true)
      else
        ""
      end
    end

    private

    def refresh_properties_view
      Pwb::ListedProperty.refresh
    rescue StandardError => e
      Rails.logger.warn "Failed to refresh properties view: #{e.message}"
    end
  end
end
