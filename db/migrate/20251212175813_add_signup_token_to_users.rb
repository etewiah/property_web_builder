class AddSignupTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_users, :signup_token, :string
    add_index :pwb_users, :signup_token, unique: true
    add_column :pwb_users, :signup_token_expires_at, :datetime
  end
end
