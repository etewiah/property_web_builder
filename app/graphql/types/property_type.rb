# frozen_string_literal: true

module Types
  class PropertyType < Types::BaseObject
    field :id, Integer
    field :created_at, GraphQL::Types::ISO8601DateTime
    field :reference, String
    field :title, String
    field :description, String

    field :area_unit, Integer
    field :plot_area, Float
    field :constructed_area, Float
    field :year_construction, Integer
    field :count_bathrooms, Integer
    field :count_bedrooms, Integer
    field :count_toilets, Integer
    field :count_garages, Integer
    field :for_sale, Boolean
    field :for_rent, Boolean

    field :energy_rating, Integer
    field :energy_performance, Float
    field :locale_code, String
    field :sold, Boolean
    field :reserved, Boolean

    field :price_rental_monthly_current_cents, Integer
    field :price_sale_current_cents, Integer
    field :currency, String

    field :address_string, String
    field :street_name, String
    field :street_number, String
    field :street_address, String
    field :postal_code, String
    field :province, String
    field :city, String
    field :region, String
    field :country, String
    field :latitude, Float
    field :longitude, Float

    # t.string "price_string"
    # t.float "price_float"
    # t.integer "price_sale_current_cents", default: 0, null: false
    # t.string "price_sale_currency", default: "EUR", null: false
    # t.integer "price_rental_monthly_current_cents", default: 0, null: false
    # t.string "price_rental_currency", default: "EUR", null: false
    # t.string "currency"

    # t.boolean "for_rent_short_term", default: false
    # t.boolean "for_rent_long_term", default: false
    # t.boolean "for_sale", default: false
    # t.boolean "for_rent", default: false
    # t.datetime "available_to_rent_from"
    # t.datetime "available_to_rent_till"
    field :prop_photos, [Types::PropPhotoType], null: false
    field :extras_for_display, GraphQL::Types::JSON, null: true

    # field :price_cents, Integer, null: false

    # def price_cents
    #   (100 * object.price).to_i
    # end
  end
end
