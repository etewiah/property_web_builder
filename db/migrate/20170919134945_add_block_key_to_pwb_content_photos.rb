class AddBlockKeyToPwbContentPhotos < ActiveRecord::Migration[5.1]
  def change
    add_column :pwb_content_photos, :block_key, :string, index: true
  end
end
