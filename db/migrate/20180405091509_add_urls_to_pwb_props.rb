class AddUrlsToPwbProps < ActiveRecord::Migration[5.1]
  def change
    # should have added an array for video_urls
    # and a details json col for extra info..
    add_column :pwb_props, :neighborhood, :string
    add_column :pwb_props, :import_url, :string
    add_column :pwb_props, :related_urls, :json, default: {}
    # should not have added slug directly as below - needs to 
    # be a globalize (translatable) col
    # along with description_short
    add_column :pwb_props, :slug, :string
    # might index above if I end up using it in place of id, index: true
    remove_index :pwb_props, :reference
    add_index :pwb_props, :reference
    # above to remove unique constraint on reference
  end
end
