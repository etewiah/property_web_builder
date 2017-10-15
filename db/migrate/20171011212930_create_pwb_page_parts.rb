class CreatePwbPageParts < ActiveRecord::Migration[5.1]
  def change
    create_table :pwb_page_parts do |t|
      t.boolean :is_rails_part, default: false
      t.boolean :show_in_editor, default: true
      t.integer :order_in_editor

      t.string :page_part_key, index: true
      t.string :page_slug, index: true
      t.text :template

      # used to decide how to lay out the editor 
      t.json :editor_setup, default: {}

      # contains the text strings (for each locale)
      # that will be merged with the template
      t.json :block_contents, default: {}

      # though currently (oct 2017) not implemented
      # below will allow future use case of per theme or locale templates
      t.string :theme_name
      t.string :locale

      t.integer :flags, null: false, default: 0
      t.timestamps
    end
    add_index :pwb_page_parts, [:page_part_key, :page_slug]

  end
end
