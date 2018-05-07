class CreatePwbWebsitePhotos < ActiveRecord::Migration[5.1]
  def change
    create_table :pwb_website_photos do |t|
      t.string :photo_key
      t.string :image
      t.string :description
      t.string :folder, default: "weebrix"
      t.integer :file_size
      # t.json :process_options, default: {} 
      # t.string :height
      # t.string :width
      # might need some other details if
      # I enable image watermarking
      # t.integer :sort_order
      t.timestamps
    end
    add_index :pwb_website_photos, :photo_key
  end
end
