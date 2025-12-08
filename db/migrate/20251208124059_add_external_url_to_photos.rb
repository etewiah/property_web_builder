class AddExternalUrlToPhotos < ActiveRecord::Migration[8.0]
  def change
    # Add external_url to all photo models
    # When set, this URL is used instead of the ActiveStorage attachment
    add_column :pwb_prop_photos, :external_url, :string
    add_column :pwb_content_photos, :external_url, :string
    add_column :pwb_website_photos, :external_url, :string
  end
end
