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
      t.string :email
      t.string :skype
      t.string :company_id
      t.integer :company_id_type
      t.string :url

      t.integer :primary_address_id
      t.integer :secondary_address_id
      t.integer :flags
      t.integer :flags, :null => false, :default => 0
      t.integer :payment_plan_id
      t.json :social_media, default: '{}'

      t.json :details, default: '{}'

      t.timestamps null: false
    end
    add_index :pwb_agencies, :company_name
    add_index :pwb_agencies, :company_id, unique: true

  end
end
