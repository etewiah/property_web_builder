class AddWebsiteIdToTables < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_props, :website_id, :integer
    add_index :pwb_props, :website_id

    add_column :pwb_pages, :website_id, :integer
    add_index :pwb_pages, :website_id

    add_column :pwb_contents, :website_id, :integer
    add_index :pwb_contents, :website_id

    add_column :pwb_links, :website_id, :integer
    add_index :pwb_links, :website_id

    add_column :pwb_agencies, :website_id, :integer
    add_index :pwb_agencies, :website_id
  end
end
