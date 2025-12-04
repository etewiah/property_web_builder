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
  class ListedProperty < ApplicationRecord
    self.table_name = 'pwb_properties'
    self.primary_key = 'id'

    # Associations (read-only, via the realty_asset_id which is our primary key)
    belongs_to :website, class_name: 'Pwb::Website', optional: true
    has_many :prop_photos, class_name: 'Pwb::PropPhoto', foreign_key: 'realty_asset_id', primary_key: 'id'
    has_many :features, class_name: 'Pwb::Feature', foreign_key: 'realty_asset_id', primary_key: 'id'

    # Underlying models for write operations
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
    # Monetize (for price display)
    # ============================================

    monetize :price_sale_current_cents, with_model_currency: :price_sale_current_currency, allow_nil: true
    monetize :price_rental_monthly_current_cents, with_model_currency: :price_rental_monthly_current_currency, allow_nil: true
    monetize :price_rental_monthly_low_season_cents, with_model_currency: :price_rental_monthly_current_currency, allow_nil: true
    monetize :price_rental_monthly_high_season_cents, with_model_currency: :price_rental_monthly_current_currency, allow_nil: true
    monetize :price_rental_monthly_for_search_cents, with_model_currency: :price_rental_monthly_current_currency, allow_nil: true
    monetize :commission_cents, with_model_currency: :commission_currency, allow_nil: true

    # ============================================
    # Scopes (matching Pwb::Prop interface)
    # ============================================

    scope :visible, -> { where(visible: true) }
    scope :for_sale, -> { where(for_sale: true) }
    scope :for_rent, -> { where(for_rent: true) }
    scope :highlighted, -> { where(highlighted: true) }

    scope :property_type, ->(property_type) { where(prop_type_key: property_type) }
    scope :property_state, ->(property_state) { where(prop_state_key: property_state) }

    # Price range scopes
    scope :for_sale_price_from, ->(minimum_price) { where("price_sale_current_cents >= ?", minimum_price.to_s) }
    scope :for_sale_price_till, ->(maximum_price) { where("price_sale_current_cents <= ?", maximum_price.to_s) }
    scope :for_rent_price_from, ->(minimum_price) { where("price_rental_monthly_for_search_cents >= ?", minimum_price.to_s) }
    scope :for_rent_price_till, ->(maximum_price) { where("price_rental_monthly_for_search_cents <= ?", maximum_price.to_s) }

    # Room count scopes
    scope :count_bathrooms, ->(min_count) { where("count_bathrooms >= ?", min_count.to_s) }
    scope :count_bedrooms, ->(min_count) { where("count_bedrooms >= ?", min_count.to_s) }
    scope :bathrooms_from, ->(min_count) { where("count_bathrooms >= ?", min_count.to_s) }
    scope :bedrooms_from, ->(min_count) { where("count_bedrooms >= ?", min_count.to_s) }

    # ============================================
    # Title/Description (from listing via Mobility)
    # ============================================
    # Title and description are marketing text stored on the listing,
    # not the underlying RealtyAsset. We check sale_listing first,
    # then rental_listing.

    def title
      sale_listing&.title || rental_listing&.title
    end

    def description
      sale_listing&.description || rental_listing&.description
    end

    # Dynamic locale-specific title/description accessors
    I18n.available_locales.each do |locale|
      define_method("title_#{locale}") do
        sale_listing&.send("title_#{locale}") || rental_listing&.send("title_#{locale}")
      end

      define_method("description_#{locale}") do
        sale_listing&.send("description_#{locale}") || rental_listing&.send("description_#{locale}")
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
    # Price Methods
    # ============================================

    def contextual_price(rent_or_sale)
      rent_or_sale ||= for_rent ? "for_rent" : "for_sale"

      if rent_or_sale == "for_rent"
        price_rental_monthly_for_search
      else
        price_sale_current
      end
    end

    def contextual_price_with_currency(rent_or_sale)
      price = contextual_price(rent_or_sale)
      return nil if price.nil? || price.zero?
      price.format(no_cents: true)
    end

    def rental_price
      if for_rent_short_term
        lowest_short_term_price || price_rental_monthly_current
      else
        price_rental_monthly_current
      end
    end

    def lowest_short_term_price
      prices = [
        price_rental_monthly_low_season,
        price_rental_monthly_current,
        price_rental_monthly_high_season
      ].reject { |p| p.nil? || p.cents < 1 }
      prices.min
    end

    # ============================================
    # URL Methods
    # ============================================

    def url_friendly_title
      title && title.length > 2 ? title.parameterize : "show"
    end

    def contextual_show_path(rent_or_sale)
      rent_or_sale ||= for_rent ? "for_rent" : "for_sale"

      if rent_or_sale == "for_rent"
        Rails.application.routes.url_helpers.prop_show_for_rent_path(
          locale: I18n.locale,
          id: id,
          url_friendly_title: url_friendly_title
        )
      else
        Rails.application.routes.url_helpers.prop_show_for_sale_path(
          locale: I18n.locale,
          id: id,
          url_friendly_title: url_friendly_title
        )
      end
    end

    # ============================================
    # Search (class method from Pwb::Prop)
    # ============================================

    def self.properties_search(**search_filtering_params)
      currency_string = search_filtering_params[:currency] || "usd"
      currency = Money::Currency.find(currency_string)

      if search_filtering_params[:sale_or_rental] == "rental"
        search_results = all.visible.for_rent
      else
        search_results = all.visible.for_sale
      end

      search_filtering_params.each do |key, value|
        next if value == "none" || key == :sale_or_rental || key == :currency

        price_fields = [:for_sale_price_from, :for_sale_price_till, :for_rent_price_from, :for_rent_price_till]
        if price_fields.include?(key)
          value = value.gsub(/\D/, "").to_i * currency.subunit_to_unit
        end
        search_results = search_results.public_send(key, value) if value.present?
      end

      search_results
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
