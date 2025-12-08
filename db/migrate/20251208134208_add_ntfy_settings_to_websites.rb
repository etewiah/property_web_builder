class AddNtfySettingsToWebsites < ActiveRecord::Migration[8.0]
  def change
    # ntfy.sh push notification settings per website
    add_column :pwb_websites, :ntfy_enabled, :boolean, default: false, null: false
    add_column :pwb_websites, :ntfy_server_url, :string, default: 'https://ntfy.sh'
    add_column :pwb_websites, :ntfy_topic_prefix, :string
    add_column :pwb_websites, :ntfy_access_token, :string

    # Notification channel toggles - which events trigger notifications
    add_column :pwb_websites, :ntfy_notify_inquiries, :boolean, default: true, null: false
    add_column :pwb_websites, :ntfy_notify_listings, :boolean, default: true, null: false
    add_column :pwb_websites, :ntfy_notify_users, :boolean, default: false, null: false
    add_column :pwb_websites, :ntfy_notify_security, :boolean, default: true, null: false
  end
end
