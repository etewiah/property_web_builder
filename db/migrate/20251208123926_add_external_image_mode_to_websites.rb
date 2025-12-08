class AddExternalImageModeToWebsites < ActiveRecord::Migration[8.0]
  def change
    # When true, images are stored as external URLs instead of uploaded to ActiveStorage
    add_column :pwb_websites, :external_image_mode, :boolean, default: false, null: false
  end
end
