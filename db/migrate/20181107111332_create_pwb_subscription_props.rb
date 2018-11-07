class CreatePwbSubscriptionProps < ActiveRecord::Migration[5.1]
  def change
    create_table :pwb_subscription_props do |t|
      t.integer :prop_id, index: true
      t.integer :subscription_id, index: true
      t.integer :flags, default: 0, index: true, null: false
      t.timestamps
    end
    # add_index :pwb_subscription_props, :prop_id, :subscription_id
  end
end
