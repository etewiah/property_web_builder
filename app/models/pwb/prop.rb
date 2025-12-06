# frozen_string_literal: true

module Pwb
  # Prop is the legacy property model (before normalization to RealtyAsset/Listings).
  # Still used for backwards compatibility.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::Prop for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  class Prop < ApplicationRecord
    extend Mobility

    self.table_name = 'pwb_props'

    belongs_to :website, class_name: 'Pwb::Website', optional: true

    # Mobility translations with container backend (single JSONB column)
    translates :title, :description

    attribute :area_unit, :integer
    enum :area_unit, { sqmt: 0, sqft: 1 }

    geocoded_by :geocodeable_address do |obj, results|
      if (geo = results.first)
        obj.longitude = geo.longitude
        obj.latitude = geo.latitude
        obj.city = geo.city
        obj.street_number = geo.street_number
        obj.street_address = geo.street_address
        obj.postal_code = geo.postal_code
        obj.province = geo.province
        obj.region = geo.state
        obj.country = geo.country
      end
    end

    monetize :price_sale_current_cents, with_model_currency: :currency, allow_nil: true
    monetize :price_sale_original_cents, with_model_currency: :currency
    monetize :price_rental_monthly_current_cents, with_model_currency: :currency
    monetize :price_rental_monthly_original_cents, with_model_currency: :currency
    monetize :price_rental_monthly_low_season_cents, with_model_currency: :currency
    monetize :price_rental_monthly_high_season_cents, with_model_currency: :currency
    monetize :price_rental_monthly_standard_season_cents, with_model_currency: :currency
    monetize :price_rental_monthly_for_search_cents, with_model_currency: :currency
    monetize :commission_cents, with_model_currency: :currency
    monetize :service_charge_yearly_cents, with_model_currency: :currency

    has_many :prop_photos, -> { order('sort_order asc') }, class_name: 'Pwb::PropPhoto'
    has_many :features, class_name: 'Pwb::Feature'

    scope :for_rent, -> { where('for_rent_short_term OR for_rent_long_term') }
    scope :for_sale, -> { where(for_sale: true) }
    scope :visible, -> { where(visible: true) }
    scope :in_zone, ->(key) { where(zone_key: key) }
    scope :in_locality, ->(key) { where(locality_key: key) }
    scope :property_type, ->(property_type) { where(prop_type_key: property_type) }
    scope :property_state, ->(property_state) { where(prop_state_key: property_state) }
    scope :for_rent_price_from, ->(minimum_price) { where('price_rental_monthly_for_search_cents >= ?', minimum_price.to_s) }
    scope :for_rent_price_till, ->(maximum_price) { where('price_rental_monthly_for_search_cents <= ?', maximum_price.to_s) }
    scope :for_sale_price_from, ->(minimum_price) { where('price_sale_current_cents >= ?', minimum_price.to_s) }
    scope :for_sale_price_till, ->(maximum_price) { where('price_sale_current_cents <= ?', maximum_price.to_s) }
    scope :count_bathrooms, ->(min_count_bathrooms) { where('count_bathrooms >= ?', min_count_bathrooms.to_s) }
    scope :count_bedrooms, ->(min_count_bedrooms) { where('count_bedrooms >= ?', min_count_bedrooms.to_s) }
    scope :bathrooms_from, ->(min_count_bathrooms) { where('count_bathrooms >= ?', min_count_bathrooms.to_s) }
    scope :bedrooms_from, ->(min_count_bedrooms) { where('count_bedrooms >= ?', min_count_bedrooms.to_s) }

    def geocodeable_address
      "#{street_address} , #{city} , #{province} , #{postal_code}"
    end

    def has_garage
      count_garages && count_garages.positive?
    end

    def for_rent
      for_rent_short_term || for_rent_long_term
    end

    def show_map
      latitude.present? && longitude.present? && !hide_map
    end

    def geocode_address!
      geocode
    end

    def geocode_address_if_needed!
      return if latitude.present? && longitude.present?

      geocode_address!
    end

    def needs_geocoding?
      geocodeable_address.present? && (latitude.blank? || longitude.blank?)
    end

    def get_features
      Hash[features.map { |key, _value| [key.feature_key, true] }]
    end

    def set_features=(features_json)
      features_json.keys.each do |feature_key|
        if features_json[feature_key] == 'true' || features_json[feature_key] == true
          features.find_or_create_by(feature_key: feature_key)
        else
          features.where(feature_key: feature_key).delete_all
        end
      end
    end

    def extras_for_display
      merged_extras = []
      get_features.keys.each do |extra|
        translated_option_key = I18n.t extra
        merged_extras.push translated_option_key
      end
      merged_extras.sort { |w1, w2| w1.casecmp(w2) }
    end

    def ordered_photo(number)
      prop_photos[number - 1] if prop_photos.length >= number
    end

    def primary_image_url
      if prop_photos.length.positive? && ordered_photo(1).image.attached?
        Rails.application.routes.url_helpers.rails_blob_path(ordered_photo(1).image, only_path: true)
      else
        ''
      end
    end

    def url_friendly_title
      if title && title.length > 2
        title.parameterize
      else
        'show'
      end
    end

    def contextual_show_path(rent_or_sale)
      rent_or_sale ||= for_rent ? 'for_rent' : 'for_sale'
      if rent_or_sale == 'for_rent'
        Rails.application.routes.url_helpers.prop_show_for_rent_path(locale: I18n.locale, id: id, url_friendly_title: url_friendly_title)
      else
        Rails.application.routes.url_helpers.prop_show_for_sale_path(locale: I18n.locale, id: id, url_friendly_title: url_friendly_title)
      end
    end

    def contextual_price(rent_or_sale)
      rent_or_sale ||= for_rent ? 'for_rent' : 'for_sale'
      if rent_or_sale == 'for_rent'
        price_rental_monthly_for_search
      else
        price_sale_current
      end
    end

    def contextual_price_with_currency(rent_or_sale)
      price = contextual_price(rent_or_sale)
      price.zero? ? nil : price.format(no_cents: true)
    end

    def rental_price
      rental_price = lowest_short_term_price || 0 if for_rent_short_term
      rental_price = price_rental_monthly_current || 0 unless rental_price&.positive?
      rental_price&.positive? ? rental_price : nil
    end

    def lowest_short_term_price
      prices_array = [price_rental_monthly_low_season, price_rental_monthly_standard_season, price_rental_monthly_high_season]
      prices_array.reject! { |a| a.cents < 1 }
      prices_array.min
    end

    def self.properties_search(**search_filtering_params)
      currency_string = search_filtering_params[:currency] || 'usd'
      currency = Money::Currency.find(currency_string)

      search_results = if search_filtering_params[:sale_or_rental] == 'rental'
                         all.visible.for_rent
                       else
                         all.visible.for_sale
                       end

      search_filtering_params.each do |key, value|
        next if value == 'none' || key == :sale_or_rental || key == :currency

        price_fields = %i[for_sale_price_from for_sale_price_till for_rent_price_from for_rent_price_till]
        value = value.gsub(/\D/, '').to_i * currency.subunit_to_unit if price_fields.include?(key)
        search_results = search_results.public_send(key, value) if value.present?
      end
      search_results
    end

    def as_json(options = nil)
      super(options).tap do |hash|
        hash['prop_photos'] = prop_photos.map do |photo|
          if photo.image.attached?
            { 'image' => Rails.application.routes.url_helpers.rails_blob_path(photo.image, only_path: true) }
          else
            { 'image' => nil }
          end
        end
      end
    end

    before_save :set_rental_search_price
    after_create :set_defaults

    private

    def set_defaults
      current_website = Pwb::Current.website || website || Pwb::Website.first
      return if current_website.nil?

      if current_website.default_currency.present?
        self.currency = current_website.default_currency
        save
      end
      if current_website.default_area_unit.present?
        self.area_unit = current_website.default_area_unit
        save
      end
    end

    def set_rental_search_price
      self.price_rental_monthly_for_search = rental_price
    end
  end
end
