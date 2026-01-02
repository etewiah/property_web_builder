# frozen_string_literal: true

class CreatePwbSavedSearches < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_saved_searches do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      # User identification (no login required)
      t.string :email, null: false
      t.string :name # Auto-generated or user-provided search name

      # Search criteria stored as JSON
      t.jsonb :search_criteria, null: false, default: {}

      # Alert settings
      t.integer :alert_frequency, null: false, default: 0 # enum: none, daily, weekly
      t.boolean :enabled, null: false, default: true

      # Tracking
      t.datetime :last_run_at
      t.integer :last_result_count, default: 0
      t.jsonb :seen_property_refs, null: false, default: [] # Track seen properties to find "new" ones

      # Security
      t.string :unsubscribe_token, null: false
      t.string :manage_token, null: false # For accessing manage page without login

      # Email verification (optional)
      t.boolean :email_verified, null: false, default: false
      t.string :verification_token
      t.datetime :verified_at

      t.timestamps
    end

    add_index :pwb_saved_searches, :email
    add_index :pwb_saved_searches, [:website_id, :email]
    add_index :pwb_saved_searches, :unsubscribe_token, unique: true
    add_index :pwb_saved_searches, :manage_token, unique: true
    add_index :pwb_saved_searches, :verification_token, unique: true
    add_index :pwb_saved_searches, [:website_id, :enabled, :alert_frequency],
              name: "index_saved_searches_for_alerts"
  end
end
