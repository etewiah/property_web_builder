class AddConfigFieldsToPwbWebsites < ActiveRecord::Migration[5.1]
  def change
    add_column :pwb_websites, :search_config_rent, :json, default: {}
    add_column :pwb_websites, :search_config_buy, :json, default: {}
    add_column :pwb_websites, :search_config_landing, :json, default: {}
    add_column :pwb_websites, :admin_config, :json, default: {}
    add_column :pwb_websites, :styles_config, :json, default: {}
    add_column :pwb_websites, :imports_config, :json, default: {}
    add_column :pwb_websites, :whitelabel_config, :json, default: {}
    add_column :pwb_websites, :exchange_rates, :json, default: {}
    add_column :pwb_websites, :favicon_url, :string
    add_column :pwb_websites, :main_logo_url, :string
    add_column :pwb_websites, :maps_api_key, :string
    add_column :pwb_websites, :recaptcha_key, :string
  end
end


