class AddSeoFieldsToWebsites < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_websites, :default_meta_description, :text
    add_column :pwb_websites, :default_seo_title, :string
  end
end
