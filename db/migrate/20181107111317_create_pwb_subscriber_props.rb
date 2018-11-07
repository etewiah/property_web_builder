class CreatePwbSubscriberProps < ActiveRecord::Migration[5.1]
  def change
    create_table :pwb_subscriber_props do |t|
      t.integer :prop_id, index: true
      t.integer :subscriber_id, index: true
      t.integer :flags, default: 0, index: true, null: false
      t.timestamps
    end
    # add_index :pwb_subscriber_props, :prop_id, :subscriber_id
  end
end
