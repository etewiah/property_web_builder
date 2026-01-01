class AddExternalFeedToWebsites < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_websites, :external_feed_enabled, :boolean, default: false, null: false
    add_column :pwb_websites, :external_feed_provider, :string
    add_column :pwb_websites, :external_feed_config, :json, default: {}

    add_index :pwb_websites, :external_feed_enabled
    add_index :pwb_websites, :external_feed_provider
  end
end
