class AddSubdomainToWebsites < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_websites, :subdomain, :string
    add_index :pwb_websites, :subdomain, unique: true
  end
end
