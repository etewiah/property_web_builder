class CreatePwbPropPhotos < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_prop_photos do |t|
      t.integer :prop_id
      t.string :image
      t.string :description
      t.string :folder
      t.integer :file_size

      t.integer :sort_order
      t.timestamps null: false
    end
    add_index :pwb_prop_photos, :prop_id
  end
end
