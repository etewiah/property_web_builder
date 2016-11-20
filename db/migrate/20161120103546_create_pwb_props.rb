class CreatePwbProps < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_props do |t|

      t.string   :reference

      t.integer  :year_construction, default: 0, null: false
      t.integer  :count_bedrooms, default: 0, null: false
      t.integer  :count_bathrooms, default: 0, null: false
      t.integer  :count_toilets, default: 0, null: false
      t.integer  :count_garages, default: 0, null: false
      t.float    :plot_area, default: 0, null: false
      t.float    :constructed_area, default: 0, null: false
      t.integer  :energy_rating
      t.float    :energy_performance
      # t.string   "title"
      # t.text     "description"
      # t.text     "details"
      t.integer  :flags, default: 0, null: false

      # booleans used in scopes
      t.boolean :furnished, default: false
      t.boolean :sold, default: false
      t.boolean :reserved, default: false
      t.boolean :highlighted, default: false
      t.boolean :archived, default: false
      # when above is set to true, below needs to be set to false
      t.boolean :visible, default: false

      t.boolean :for_rent_short_term, default: false
      t.boolean :for_rent_long_term, default: false
      t.boolean :for_sale, default: false
      t.boolean :hide_map, default: false
      t.boolean :obscure_map, default: false
      t.boolean :portals_enabled, default: false
      # if I used flag shih tzu for above, I couldn't make queries like:
      # Property.where('for_rent_short_term OR for_rent_long_term')


      t.datetime :deleted_at
      t.datetime :active_from
      t.datetime :available_to_rent_from
      t.datetime :available_to_rent_till

      t.monetize :price_sale_current
      t.monetize :price_sale_original
      # above will create below in schema.rb:
      # t.integer  "price_sale_original_cents",                     default: 0,     null: false
      # t.string   "price_sale_original_currency",                  default: "EUR", null: false

      t.monetize :price_rental_monthly_current
      t.monetize :price_rental_monthly_original
      t.monetize :price_rental_monthly_low_season
      t.monetize :price_rental_monthly_high_season
      t.monetize :price_rental_monthly_standard_season
      t.monetize :commission
      t.monetize :service_charge_yearly
      t.string   :currency

      t.string :prop_origin_key, default: "", null: false
      t.string :prop_state_key, default: "", null: false
      t.string :prop_type_key, default: "", null: false

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

      t.timestamps
    end

    add_index :pwb_props, :visible
    add_index :pwb_props, :flags
    add_index :pwb_props, :for_rent_short_term
    add_index :pwb_props, :for_rent_long_term
    add_index :pwb_props, :for_sale
    add_index :pwb_props, :highlighted
    add_index :pwb_props, :archived
    add_index :pwb_props, :reference, unique: true
    add_index :pwb_props, :price_rental_monthly_current_cents
    add_index :pwb_props, :price_sale_current_cents

    # add_index :pwb_props, :locality
    # add_index :pwb_props, :zone
    # https://github.com/alexreisner/geocoder
    add_index :pwb_props, [:latitude, :longitude]
  end
end
