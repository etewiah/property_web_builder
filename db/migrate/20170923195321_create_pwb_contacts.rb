class CreatePwbContacts < ActiveRecord::Migration[5.1]
  def change
    create_table :pwb_contacts do |t|
      t.string :first_name, index: true
      t.string :last_name, index: true
      t.string :other_names
      t.integer :title, default: 0, index: true
      t.string :primary_phone_number, index: true
      t.string :other_phone_number
      t.string :fax
      t.string :nationality
      t.string :primary_email, index: true, unique: true
      t.string :other_email
      t.string :skype_id
      t.string :facebook_id
      t.string :linkedin_id
      t.string :twitter_id
      t.string :website
      t.string :documentation_id, index: true, unique: true
      t.integer :documentation_type
      t.integer :user_id
      t.integer :primary_address_id
      t.integer :secondary_address_id
      t.integer :flags, null: false, default: 0
      t.json :details, default: {}

      t.timestamps null: false
    end

    add_index :pwb_contacts, [:first_name, :last_name]
  end
end
