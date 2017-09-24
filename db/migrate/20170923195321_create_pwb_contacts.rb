class CreatePwbContacts < ActiveRecord::Migration[5.1]
  def change
    create_table :pwb_contacts do |t|
      t.string :first_name, index: true
      t.string :last_name, index: true
      t.string :other_names
      t.integer :title, default: 0, index: true
      t.string :phone_number_primary, index: true
      t.string :phone_number_other
      t.string :fax
      t.string :nationality
      t.string :email
      t.string :skype_id
      t.string :facebook_id
      t.string :linkedin_id
      t.string :twitter_id
      t.string :website
      t.string :documentation_id
      t.integer :documentation_type
      t.integer :user_id
      t.integer :primary_address_id
      t.integer :secondary_address_id
      t.integer :flags, null: false, default: 0
      t.json :details, default: {}

      t.timestamps null: false
      t.timestamps
    end
  end
end
