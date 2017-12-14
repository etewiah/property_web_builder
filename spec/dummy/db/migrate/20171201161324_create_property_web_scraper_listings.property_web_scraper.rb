# This migration comes from property_web_scraper (originally 20170628201113)
class CreatePropertyWebScraperListings < ActiveRecord::Migration[5.0]
  def change
    create_table :property_web_scraper_listings do |t|
      t.integer  :flags, default: 0, null: false
      t.integer  :area_unit, default: 0, null: false
      t.string   :reference
      # -1 indicates value could not be retrieved
      t.integer  :year_construction, default: 0, null: false
      t.integer  :count_bedrooms, default: 0, null: false
      t.float :count_bathrooms, default: 0, null: false
      # turns out count_bathrooms in the US can be .5, 1.5 etc
      # so need a float for above
      t.integer  :count_toilets, default: 0, null: false
      t.integer  :count_garages, default: 0, null: false
      t.float    :plot_area, default: 0, null: false
      t.float    :constructed_area, default: 0, null: false
      t.integer  :energy_rating
      t.float    :energy_performance
      t.string   :title
      t.text     :description
      t.string   :locale_code
      # t.text     details

      # booleans used in scopes
      t.boolean :furnished, default: false
      t.boolean :sold, default: false
      t.boolean :reserved, default: false

      t.boolean :for_rent_short_term, default: false
      t.boolean :for_rent_long_term, default: false
      t.boolean :for_sale, default: false
      t.boolean :for_rent, default: false

      t.datetime :available_to_rent_from
      t.datetime :available_to_rent_till

      t.string :price_string
      t.float :price_float
      t.monetize :price_sale
      # above will create below in schema.rb:
      # t.integer  "price_sale_cents",                     default: 0,     null: false
      # t.string   "price_sale_currency",                  default: "EUR", null: false
      t.monetize :price_rental

      t.string :currency

      t.string :address_string
      t.string :street_number
      t.string :street_name
      t.string :street_address
      t.string :postal_code
      t.string :province
      t.string :city
      t.string :region
      t.string :country
      t.float :latitude
      t.float :longitude

      t.datetime :last_retrieved_at
      # t.integer :import_host_id
      t.string :import_host_slug
      # for real estate agent ref:
      t.integer :re_agent_id
      t.string :import_url
      t.json :import_history, default: {}

      t.string :main_image_url
      t.text :image_urls, array: true, default: []
      t.text :related_urls, array: true, default: []
      t.text :features, array: true, default: []
      t.text :unknown_fields, array: true, default: []

      t.timestamps
    end

    add_index :property_web_scraper_listings, :flags
    add_index :property_web_scraper_listings, :price_float
    add_index :property_web_scraper_listings, :price_rental_cents
    add_index :property_web_scraper_listings, :price_sale_cents
    add_index :property_web_scraper_listings, :reference
    add_index :property_web_scraper_listings, :import_url
  end
end
