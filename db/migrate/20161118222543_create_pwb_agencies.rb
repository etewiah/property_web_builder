class CreatePwbAgencies < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_agencies do |t|
      t.string :phone_number_primary
      t.string :phone_number_mobile
      t.string :phone_number_other

      t.string :analytics_id
      t.integer :analytics_id_type

      t.string :company_name
      t.string :display_name
      t.string :email_primary
      t.string :email_for_general_contact_form
      t.string :email_for_property_contact_form
      t.string :skype
      t.string :company_id
      t.integer :company_id_type
      t.string :url

      t.integer :primary_address_id
      t.integer :secondary_address_id
      # t.integer :flags
      t.integer :flags, :null => false, :default => 0
      t.integer :payment_plan_id

      t.integer :site_template_id
      t.columnjson :site_configuration, :json, default: {}

      t.text :available_locales, array: true, default: []
      t.text :supported_locales, array: true, default: []
      t.text :available_currencies, array: true, default: []
      t.text :supported_currencies, array: true, default: []
      t.string :default_client_locale
      t.string :default_admin_locale
      t.string :default_currency

      t.json :social_media, default: {}
      t.json :details, default: {}
      t.text :raw_css

      t.timestamps null: false
    end
    # add_index :pwb_agencies, :company_name
    # add_index :pwb_agencies, :company_id, unique: true

  end
end
