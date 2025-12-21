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
  #
  #  id                                            :integer          not null, primary key
  #  active_from                                   :datetime
  #  archived                                      :boolean          default(FALSE)
  #  area_unit                                     :integer          default("sqmt")
  #  ... (schema annotations preserved)
  #
  class Prop < ApplicationRecord
    extend Mobility

    # ===================
    # Concerns
    # ===================
    include Property::Geocodable
    include Property::Priceable
    include Property::Searchable
    include Property::Displayable

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
