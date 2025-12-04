module Pwb
  class ApiExt::V1::PropResource < JSONAPI::Resource
    # Use Pwb::ListedProperty (materialized view) for read operations
    model_name 'Pwb::ListedProperty'

    # NOTE: This resource is READ-ONLY because it's backed by a materialized view.
    # For write operations, use the underlying models directly.

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

    attributes :photos, :property_photos, :extras
    attributes :street_address, :street_number, :postal_code
    attributes :city, :region, :currency
    attributes :country, :longitude, :latitude

    attributes :count_bathrooms, :count_bedrooms, :count_garages, :count_toilets
    attributes :constructed_area, :year_construction, :plot_area
    attributes :prop_type_key, :prop_state_key, :prop_origin_key

    attributes :for_sale, :for_rent, :for_rent_short_term, :for_rent_long_term
    attributes :obscure_map, :hide_map

    attributes :price_sale_current_cents
    attributes :price_rental_monthly_current_cents
    attributes :price_rental_monthly_low_season_cents, :price_rental_monthly_high_season_cents
    attributes :visible, :highlighted, :reference

    def extras
      @model.get_features
    end

    def property_photos
      @model.prop_photos
    end

    def photos
      @model.prop_photos
    end
  end
end
