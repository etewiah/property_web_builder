class CreatePwbAddresses < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_addresses do |t|
      # t.integer :address_category
      t.float :longitude
      t.float :latitude
      t.string :street_number
      t.string :street_address
      t.string :postal_code
      t.string :city
      t.string :region
      t.string :country

      t.timestamps null: false
    end
  end
end
