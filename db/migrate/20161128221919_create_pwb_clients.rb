class CreatePwbClients < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_clients do |t|
      t.string :first_names
      t.string :last_names
      t.string :client_title
      t.string :phone_number_primary
      t.string :phone_number_other
      t.string :fax
      t.string :nationality
      t.string :email
      t.string :skype
      t.string :documentation_id
      t.integer :documentation_type
      t.integer :user_id
      t.integer :address_id
      t.integer :flags, :null => false, :default => 0
      t.json :details, default: {}

      t.timestamps null: false
    end

    add_index :pwb_clients, :documentation_id, unique: true
    add_index :pwb_clients, [:first_names, :last_names]
    add_index :pwb_clients, :email, unique: true

  end
end
