class AddSlugToWebsites < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_websites, :slug, :string
    add_index :pwb_websites, :slug
  end
end
