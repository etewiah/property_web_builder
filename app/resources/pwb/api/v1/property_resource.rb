module Pwb
  class Api::V1::PropertyResource < JSONAPI::Resource
    # Use Pwb::ListedProperty (materialized view) for read operations
    model_name "Pwb::ListedProperty"

    # NOTE: This resource is READ-ONLY because it's backed by a materialized view.
    # For write operations, use the underlying models directly:
    #   - Pwb::RealtyAsset (physical property data)
    #   - Pwb::SaleListing (sale transaction data)
    #   - Pwb::RentalListing (rental transaction data)

    attributes :title, :description
    attributes :title_en, :description_en
    attributes :title_es, :description_es
    attributes :title_it, :description_it
    attributes :title_de, :description_de
    attributes :title_ru, :description_ru
    attributes :title_pt, :description_pt
    attributes :title_fr, :description_fr
    attributes :title_tr, :description_tr
    attributes :title_nl, :description_nl
    attributes :title_vi, :description_vi
    attributes :title_ar, :description_ar
    attributes :title_ca, :description_ca
    attributes :title_pl, :description_pl
    attributes :title_ro, :description_ro
    attributes :title_ko, :description_ko
    attributes :title_bg, :description_bg

    attributes :photos, :property_photos, :extras
    attributes :street_address, :street_name, :street_number, :postal_code
    attributes :city, :region, :currency
    attributes :country, :longitude, :latitude

    attributes :count_bathrooms, :count_bedrooms, :count_garages, :count_toilets
    attributes :constructed_area, :year_construction, :plot_area
    attributes :prop_type_key, :prop_state_key, :prop_origin_key

    attributes :for_sale, :for_rent, :for_rent_short_term, :for_rent_long_term
    attributes :hide_map, :obscure_map

    attributes :price_sale_current_cents
    attributes :price_rental_monthly_current_cents
    attributes :price_rental_monthly_low_season_cents, :price_rental_monthly_high_season_cents
    attributes :price_rental_monthly_for_search_cents
    attributes :visible, :highlighted, :reference

    def extras
      @model.get_features
    end

    def property_photos
      @model.prop_photos.map do |photo|
        photo.attributes.merge({
          "image" => photo.image.attached? ? Rails.application.routes.url_helpers.rails_blob_path(photo.image, only_path: true) : nil
        })
      end
    end

    def photos
      @model.prop_photos.map do |photo|
        photo.attributes.merge({
          "image" => photo.image.attached? ? Rails.application.routes.url_helpers.rails_blob_path(photo.image, only_path: true) : nil
        })
      end
    end

    # Scope properties to current website for multi-tenancy
    def self.records(options = {})
      current_website = Pwb::Current.website
      if current_website
        Pwb::ListedProperty.where(website_id: current_website.id)
      else
        Pwb::ListedProperty.none
      end
    end
  end
end
