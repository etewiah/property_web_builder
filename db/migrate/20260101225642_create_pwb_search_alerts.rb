# frozen_string_literal: true

class CreatePwbSearchAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_search_alerts do |t|
      t.references :saved_search, null: false, foreign_key: { to_table: :pwb_saved_searches }

      # Results
      t.jsonb :new_properties, null: false, default: [] # Array of property data snapshots
      t.integer :properties_count, null: false, default: 0
      t.integer :total_results_count, default: 0 # Total matching properties at time of search

      # Email tracking
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :opened_at
      t.datetime :clicked_at
      t.string :email_status # pending, sent, delivered, bounced, failed

      # Error tracking
      t.text :error_message

      t.timestamps
    end

    add_index :pwb_search_alerts, :sent_at
    add_index :pwb_search_alerts, [:saved_search_id, :created_at]
  end
end
