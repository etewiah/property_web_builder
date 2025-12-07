class AddIndexToUnlockTokenOnPwbUsers < ActiveRecord::Migration[8.0]
  def change
    # Add unique index on unlock_token for efficient lookups during account unlock
    # Required for Devise :lockable module to work efficiently
    add_index :pwb_users, :unlock_token, unique: true
  end
end
