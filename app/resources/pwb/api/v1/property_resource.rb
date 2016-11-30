module Pwb
  class Api::V1::PropertyResource < JSONAPI::Resource
    model_name 'Pwb::Prop'


    attributes :photos, :extras
    attributes :street_address, :street_number, :postal_code
    attributes :city, :region
    attributes :country, :longitude, :latitude

    attributes :title_es, :title_en, :title_ar, :description_es, :description_en, :description_ar, :extras

    attributes :for_sale, :for_rent_short_term, :for_rent_long_term, :obscure_map, :hide_map

    attributes :price_sale_current_cents, :price_sale_original_cents
    attributes :price_rental_monthly_current_cents, :price_rental_monthly_original_cents
    attributes :price_rental_monthly_low_season_cents, :price_rental_monthly_high_season_cents
    attributes :price_rental_monthly_standard_season_cents

    def extras
      # override needed here as I have an extras has_many r/n on property
      # which is not yet in use..
      return @model.get_extras
    end

    def photos
      photos = @model.prop_photos
      return photos
    end
  end
end
