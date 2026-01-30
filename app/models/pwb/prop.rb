# frozen_string_literal: true

module Pwb
  # Prop is the legacy property model (before normalization to RealtyAsset/Listings).
  # Still used for backwards compatibility.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::Prop for
  # tenant-scoped queries in web requests.
  #
# == Schema Information
#
# Table name: pwb_props
# Database name: primary
#
#  id                                            :integer          not null, primary key
#  active_from                                   :datetime
#  archived                                      :boolean          default(FALSE)
#  area_unit                                     :integer          default("sqmt")
#  available_to_rent_from                        :datetime
#  available_to_rent_till                        :datetime
#  city                                          :string
#  commission_cents                              :integer          default(0), not null
#  commission_currency                           :string           default("EUR"), not null
#  constructed_area                              :float            default(0.0), not null
#  count_bathrooms                               :float            default(0.0), not null
#  count_bedrooms                                :integer          default(0), not null
#  count_garages                                 :integer          default(0), not null
#  count_toilets                                 :integer          default(0), not null
#  country                                       :string
#  currency                                      :string
#  deleted_at                                    :datetime
#  energy_performance                            :float
#  energy_rating                                 :integer
#  flags                                         :integer          default(0), not null
#  for_rent_long_term                            :boolean          default(FALSE)
#  for_rent_short_term                           :boolean          default(FALSE)
#  for_sale                                      :boolean          default(FALSE)
#  furnished                                     :boolean          default(FALSE)
#  hide_map                                      :boolean          default(FALSE)
#  highlighted                                   :boolean          default(FALSE)
#  latitude                                      :float
#  longitude                                     :float
#  meta_description                              :text
#  obscure_map                                   :boolean          default(FALSE)
#  plot_area                                     :float            default(0.0), not null
#  portals_enabled                               :boolean          default(FALSE)
#  postal_code                                   :string
#  price_rental_monthly_current_cents            :integer          default(0), not null
#  price_rental_monthly_current_currency         :string           default("EUR"), not null
#  price_rental_monthly_for_search_cents         :integer          default(0), not null
#  price_rental_monthly_for_search_currency      :string           default("EUR"), not null
#  price_rental_monthly_high_season_cents        :integer          default(0), not null
#  price_rental_monthly_high_season_currency     :string           default("EUR"), not null
#  price_rental_monthly_low_season_cents         :integer          default(0), not null
#  price_rental_monthly_low_season_currency      :string           default("EUR"), not null
#  price_rental_monthly_original_cents           :integer          default(0), not null
#  price_rental_monthly_original_currency        :string           default("EUR"), not null
#  price_rental_monthly_standard_season_cents    :integer          default(0), not null
#  price_rental_monthly_standard_season_currency :string           default("EUR"), not null
#  price_sale_current_cents                      :bigint           default(0), not null
#  price_sale_current_currency                   :string           default("EUR"), not null
#  price_sale_original_cents                     :bigint           default(0), not null
#  price_sale_original_currency                  :string           default("EUR"), not null
#  prop_origin_key                               :string           default(""), not null
#  prop_state_key                                :string           default(""), not null
#  prop_type_key                                 :string           default(""), not null
#  province                                      :string
#  reference                                     :string
#  region                                        :string
#  reserved                                      :boolean          default(FALSE)
#  seo_title                                     :string
#  service_charge_yearly_cents                   :integer          default(0), not null
#  service_charge_yearly_currency                :string           default("EUR"), not null
#  sold                                          :boolean          default(FALSE)
#  street_address                                :string
#  street_name                                   :string
#  street_number                                 :string
#  translations                                  :jsonb            not null
#  visible                                       :boolean          default(FALSE)
#  year_construction                             :integer          default(0), not null
#  created_at                                    :datetime         not null
#  updated_at                                    :datetime         not null
#  website_id                                    :integer
#
# Indexes
#
#  index_pwb_props_on_archived                            (archived)
#  index_pwb_props_on_flags                               (flags)
#  index_pwb_props_on_for_rent_long_term                  (for_rent_long_term)
#  index_pwb_props_on_for_rent_short_term                 (for_rent_short_term)
#  index_pwb_props_on_for_sale                            (for_sale)
#  index_pwb_props_on_highlighted                         (highlighted)
#  index_pwb_props_on_latitude_and_longitude              (latitude,longitude)
#  index_pwb_props_on_price_rental_monthly_current_cents  (price_rental_monthly_current_cents)
#  index_pwb_props_on_price_sale_current_cents            (price_sale_current_cents)
#  index_pwb_props_on_reference                           (reference)
#  index_pwb_props_on_translations                        (translations) USING gin
#  index_pwb_props_on_visible                             (visible)
#  index_pwb_props_on_website_id                          (website_id)
#
  class Prop < ApplicationRecord
    extend Mobility

    # ===================
    # Concerns
    # ===================
    include Pwb::PropertyGeocodable
    include Pwb::PropertyPriceable
    include Pwb::PropertySearchable
    include Pwb::PropertyDisplayable

    # ===================
    # Configuration
    # ===================
    self.table_name = 'pwb_props'

    # Mobility translations with container backend
    translates :title, :description

    attribute :area_unit, :integer
    enum :area_unit, { sqmt: 0, sqft: 1 }

    # ===================
    # Associations
    # ===================
    belongs_to :website, class_name: 'Pwb::Website', optional: true
    has_many :prop_photos, -> { order('sort_order asc') }, class_name: 'Pwb::PropPhoto'
    has_many :features, class_name: 'Pwb::Feature'
    has_many :ai_generation_requests, class_name: 'Pwb::AiGenerationRequest', foreign_key: 'prop_id', dependent: :destroy

    # ===================
    # Callbacks
    # ===================
    after_create :set_defaults

    # ===================
    # Instance Methods
    # ===================

    def has_garage
      count_garages && count_garages.positive?
    end

    def for_rent
      for_rent_short_term || for_rent_long_term
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

    # ===================
    # Serialization
    # ===================

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
  end
end
