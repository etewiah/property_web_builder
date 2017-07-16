class CreatePwbPages < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_pages do |t|
      t.string :slug
      t.string :link_key
      t.string :link_path
      t.integer :sort_order
      t.boolean :visible
      t.integer :last_updated_by_user_id
      t.integer :flags, default: 0, index: true, null: false
      t.json :details, default: {}
      # t.boolean :is_page, default: false, index: true
      t.boolean :show_in_top_nav, default: false, index: true
      t.boolean :show_in_footer, default: false, index: true
      # t.boolean :key, :string, index: true
      t.timestamps null: false
    end

    add_index :pwb_pages, :link_key, :unique => true
    add_index :pwb_pages, :slug, :unique => true
  end
end
