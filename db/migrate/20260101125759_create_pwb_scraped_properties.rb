# frozen_string_literal: true

class CreatePwbScrapedProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_scraped_properties, id: :uuid do |t|
      # website uses integer/serial IDs, realty_asset uses uuid
      t.references :website, foreign_key: { to_table: :pwb_websites }, null: false
      t.references :realty_asset, type: :uuid, foreign_key: { to_table: :pwb_realty_assets }, null: true

      # Source information
      t.string :source_url, null: false
      t.string :source_url_normalized
      t.string :source_host
      t.string :source_portal

      # Raw content storage
      t.text :raw_html
      t.text :script_json

      # Extracted data
      t.jsonb :extracted_data, default: {}
      t.jsonb :extracted_images, default: []

      # Scrape metadata
      t.string :scrape_method # "auto", "manual_html"
      t.string :connector_used # "http", "playwright"
      t.boolean :scrape_successful, default: false
      t.string :scrape_error_message

      # Import workflow
      t.string :import_status, default: "pending" # "pending", "previewing", "imported", "failed"
      t.datetime :imported_at

      t.timestamps
    end

    add_index :pwb_scraped_properties, :source_url_normalized
    add_index :pwb_scraped_properties, [:website_id, :source_host]
    add_index :pwb_scraped_properties, :import_status
  end
end
