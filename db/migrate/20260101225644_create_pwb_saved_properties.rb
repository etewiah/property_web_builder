# frozen_string_literal: true

class CreatePwbSavedProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_saved_properties do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      # User identification (no login required)
      t.string :email, null: false

      # Property identification
      t.string :provider, null: false # e.g., "resales_online"
      t.string :external_reference, null: false # Property ID from provider

      # Cached property data for display without API call
      t.jsonb :property_data, null: false, default: {}

      # User additions
      t.text :notes # Optional user notes

      # Price tracking (for future notifications)
      t.integer :original_price_cents
      t.integer :current_price_cents
      t.datetime :price_changed_at

      # Security
      t.string :manage_token, null: false # For accessing favorites without login

      t.timestamps
    end

    add_index :pwb_saved_properties, :email
    add_index :pwb_saved_properties, [:website_id, :email]
    add_index :pwb_saved_properties, :manage_token, unique: true
    add_index :pwb_saved_properties, [:website_id, :provider, :external_reference],
              name: "index_saved_properties_on_provider_ref"
    add_index :pwb_saved_properties, [:email, :provider, :external_reference],
              unique: true,
              name: "index_saved_properties_unique_per_email"
  end
end
