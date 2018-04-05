class AddUrlsToPwbProps < ActiveRecord::Migration[5.1]
  def change
    add_column :pwb_props, :neighborhood, :string
    add_column :pwb_props, :import_url, :string
    add_column :pwb_props, :related_urls, :json, default: {}
    add_column :pwb_props, :slug, :string
    # might index above if I end up using it in place of id, index: true
    remove_index :pwb_props, :reference
    add_index :pwb_props, :reference
    # above to remove unique constraint on reference
  end
end
