class CreatePwbLiquidFragments < ActiveRecord::Migration[5.1]
  def change
    create_table :pwb_liquid_fragments do |t|

      # t.string :page_name, index: true
      t.string :fragment_key, index: true

      t.string :page_slug, index: true
      t.string :fragment_slug, index: true
      t.text :template



      t.integer :flags, null: false, default: 0

      # used to decide how to lay out the editor 
      t.json :editor_setup, default: {}

      # contains the text strings (for each locale)
      # that will be merged with the template
      t.json :block_contents, default: {}

      # though currenty (oct 2017) not implemented
      # below will allow future use case of per theme or locale templates
      t.string :theme_name
      t.string :locale

      t.timestamps
    end
    add_index :pwb_liquid_fragments, [:fragment_key, :page_slug]
  end
end
