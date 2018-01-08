class CreatePwbFieldKeys < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_field_keys do |t|

      t.string :global_key #i18n lookup key
      t.string :tag
      t.boolean :visible, :default => true

      # props_count allows me to know which field_keys are being used.
      # eg, a property_type like warehouse might never be used
      # I might choose not to show that property_type in the search dropdown box
      # by only showing property types with a props_count > 0
      t.integer :props_count, :null => false, :default => 0
      t.boolean :show_in_search_form, :default => true

      t.timestamps null: false
    end
    add_index :pwb_field_keys, :global_key, :unique => true
  end

end
