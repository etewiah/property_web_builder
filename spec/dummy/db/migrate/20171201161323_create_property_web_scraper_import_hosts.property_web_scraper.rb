# This migration comes from property_web_scraper (originally 20170628160331)
class CreatePropertyWebScraperImportHosts < ActiveRecord::Migration[5.0]
  def change
    create_table :property_web_scraper_import_hosts do |t|
      t.integer  :flags, default: 0, null: false
      t.string :scraper_name
      t.string :host
      t.boolean :is_https
      t.json :details, default: {}
      t.string :slug
      t.text :example_urls, array: true, default: []
      t.text :invalid_urls, array: true, default: []
      t.datetime :last_retrieval_at
      t.string :valid_url_regex
      t.string :pause_between_calls, default: "5.seconds"
      t.string :stale_age, default: "1.day"
      t.timestamps
    end

    add_index :property_web_scraper_import_hosts, :host, unique: true
  end
end
