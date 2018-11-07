class CreatePwbSubscribers < ActiveRecord::Migration[5.1]
  def change
    create_table :pwb_subscribers do |t|
      t.integer :contact_id
      t.string :subscriber_token
      t.string :subscriber_url
      t.json :subscriber_details, default: {}
      t.integer :flags, default: 0, index: true, null: false
      t.timestamps
    end
    add_index :pwb_subscribers, :contact_id
  end
end
