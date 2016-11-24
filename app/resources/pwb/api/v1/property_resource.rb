module Pwb
  class Api::V1::PropertyResource < JSONAPI::Resource
    model_name 'Pwb::Prop'


    attributes :photos, :prop_photos
    attributes :street_address, :street_number, :postal_code
    attributes :city, :region
    attributes :country, :longitude, :latitude

    attributes :price_sale_current_cents, :price_sale_original_cents
    attributes :price_rental_monthly_current_cents, :price_rental_monthly_original_cents
    attributes :price_rental_monthly_low_season_cents, :price_rental_monthly_high_season_cents
    attributes :price_rental_monthly_standard_season_cents

    def photos
      photos = @model.prop_photos
      return photos
    end
  end
end
