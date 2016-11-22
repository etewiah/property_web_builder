class CreatePwbSections < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_sections do |t|
      t.string :link_key
      t.string :link_path
      t.integer :sort_order
      t.boolean :visible
      t.timestamps null: false
    end

    add_index :pwb_sections, :link_key, :unique => true
  end
end
