class CreatePwbSubscriptions < ActiveRecord::Migration[5.1]
  def change
    create_table :pwb_subscriptions do |t|
      t.integer :contact_id
      t.string :subscription_token
      t.string :subscription_url
      t.json :subscription_details, default: {}
      t.integer :flags, default: 0, index: true, null: false
      t.timestamps
    end
    add_index :pwb_subscriptions, :contact_id
  end
end
