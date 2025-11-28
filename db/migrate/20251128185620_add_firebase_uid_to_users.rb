class AddFirebaseUidToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_users, :firebase_uid, :string
    add_index :pwb_users, :firebase_uid, unique: true
  end
end
