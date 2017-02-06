class CreatePwbWebsites < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_websites do |t|
      t.string :analytics_id
      t.integer :analytics_id_type

      # t.string :company_name
      t.string :company_display_name
      t.string :email_for_general_contact_form
      t.string :email_for_property_contact_form
      # t.string :url

      t.integer :primary_address_id
      t.integer :secondary_address_id
      t.integer :flags
      t.integer :flags, :null => false, :default => 0
      # t.integer :payment_plan_id

      t.string :theme_name
      t.string :google_font_name
      t.json :configuration, default: {}
      t.json :style_variables_for_theme, default: {}

      t.text :sale_price_options_from, array: true, default: [
        "","25,000", "50,000", "75,000", "100,000", "150,000", "250,000", "500,000", "1,000,000", "2,000,000", "5,000,000", "10,000,000"
      ]
      t.text :sale_price_options_till, array: true, default: [
        "","25,000", "50,000", "75,000", "100,000", "150,000", "250,000", "500,000", "1,000,000", "2,000,000", "5,000,000", "10,000,000"
      ]
      t.text :rent_price_options_from, array: true, default: [
        "","250", "500", "750", "1,000", "1,500", "2,500", "5,000"
      ]
      t.text :rent_price_options_till, array: true, default: [
        "","250", "500", "750", "1,000", "1,500", "2,500", "5,000"
      ]
      # t.text :available_locales, array: true, default: []
      t.text :supported_locales, array: true, default: ["en-UK"]
      # t.text :available_currencies, array: true, default: []
      # supported_currencies for when instant conversions are allowed
      t.text :supported_currencies, array: true, default: []
      t.string :default_client_locale, default: "en-UK"
      t.string :default_admin_locale, default: "en-UK"
      t.string :default_currency, default: "EUR"
      t.integer :default_area_unit, default: 0

      t.json :social_media, default: {}
      t.text :raw_css

      t.timestamps
    end
  end
end
