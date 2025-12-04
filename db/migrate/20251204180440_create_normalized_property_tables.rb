class CreateNormalizedPropertyTables < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # 1. Realty Assets (The Physical Property)
    create_table :pwb_realty_assets, id: :uuid do |t|
      t.string :reference
      t.string :title
      t.text :description
      
      # Physical Attributes
      t.integer :year_construction, default: 0
      t.integer :count_bedrooms, default: 0
      t.float :count_bathrooms, default: 0.0
      t.integer :count_toilets, default: 0
      t.integer :count_garages, default: 0
      t.float :plot_area, default: 0.0
      t.float :constructed_area, default: 0.0
      t.integer :energy_rating
      t.float :energy_performance
      
      # Address / Location
      t.string :street_number
      t.string :street_name
      t.string :street_address
      t.string :postal_code
      t.string :city
      t.string :region
      t.string :country
      t.float :latitude
      t.float :longitude
      
      # Keys/Metadata
      t.string :prop_origin_key
      t.string :prop_state_key
      t.string :prop_type_key
      t.integer :website_id, index: true
      
      t.timestamps
    end

    # 2. Sale Listings (The Transaction)
    create_table :pwb_sale_listings, id: :uuid do |t|
      t.references :realty_asset, type: :uuid, foreign_key: { to_table: :pwb_realty_assets }
      t.string :reference # Can be different from asset reference
      
      # Status Flags
      t.boolean :visible, default: false
      t.boolean :highlighted, default: false
      t.boolean :archived, default: false
      t.boolean :reserved, default: false
      t.boolean :furnished, default: false
      
      # Financials
      t.bigint :price_sale_current_cents, default: 0
      t.string :price_sale_current_currency, default: 'EUR'
      t.bigint :commission_cents, default: 0
      t.string :commission_currency, default: 'EUR'
      
      t.timestamps
    end

    # 3. Rental Listings (The Transaction)
    create_table :pwb_rental_listings, id: :uuid do |t|
      t.references :realty_asset, type: :uuid, foreign_key: { to_table: :pwb_realty_assets }
      t.string :reference
      
      # Status Flags
      t.boolean :visible, default: false
      t.boolean :highlighted, default: false
      t.boolean :archived, default: false
      t.boolean :reserved, default: false
      t.boolean :furnished, default: false
      
      # Rental Specifics
      t.boolean :for_rent_short_term, default: false
      t.boolean :for_rent_long_term, default: false
      
      # Financials
      t.bigint :price_rental_monthly_current_cents, default: 0
      t.string :price_rental_monthly_current_currency, default: 'EUR'
      t.bigint :price_rental_monthly_low_season_cents, default: 0
      t.bigint :price_rental_monthly_high_season_cents, default: 0
      
      t.timestamps
    end
  end
end
