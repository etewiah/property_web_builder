class AddWebsiteToContactsMessagesAndPhotos < ActiveRecord::Migration[8.0]
  def change
    add_reference :pwb_contacts, :website, foreign_key: { to_table: :pwb_websites }
    rename_column :pwb_contacts, :website, :website_url

    add_reference :pwb_messages, :website, foreign_key: { to_table: :pwb_websites }
    add_reference :pwb_website_photos, :website, foreign_key: { to_table: :pwb_websites }
  end
end
