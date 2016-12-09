class CreatePwbContentPhotos < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_content_photos do |t|
      t.integer :content_id
      t.string :image
      t.string :description
      t.string :folder
      t.integer :file_size

      # To allow ordering of photos
      t.integer :sort_order
      t.timestamps null: false
    end
    add_index :pwb_content_photos, :content_id
  end
end
