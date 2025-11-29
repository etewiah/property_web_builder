class AddWebsiteIdToPwbUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :pwb_users, :website_id, :integer
    add_index :pwb_users, :website_id
  end
end
