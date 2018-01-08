class CreatePwbLinks < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_links do |t|
      # t.text :params???
      t.string :slug
      t.string :parent_slug
      # below for association with pages
      t.string :page_slug, index: true
      t.string :icon_class
      t.string :href_class
      t.string :href_target
      t.boolean :is_external, default: false
      t.string :link_url
      # above for external links, below for internal
      t.string :link_path
      # below is a comma separated list of params for an
      # internal path such as "show_page_path"
      t.string :link_path_params
      t.boolean :visible, default: true
      t.boolean :is_deletable, default: false
      t.integer :flags, default: 0, index: true, null: false
      t.integer :sort_order, default: 0
      t.integer :placement, default: 0, index: true
      t.timestamps
    end
    add_index :pwb_links, :slug, unique: true

  end
end
