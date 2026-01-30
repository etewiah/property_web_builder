# frozen_string_literal: true

class CreatePwbWebsiteIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_website_integrations do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      # Classification
      t.string :category, null: false    # ai, crm, email_marketing, analytics, payment, maps, storage, etc.
      t.string :provider, null: false    # anthropic, openai, zoho, mailchimp, stripe, google_maps, etc.

      # Configuration
      t.text :credentials                # Encrypted - API keys, secrets, tokens
      t.jsonb :settings, default: {}     # Non-sensitive provider-specific settings

      # State
      t.boolean :enabled, default: true
      t.datetime :last_used_at
      t.datetime :last_error_at
      t.text :last_error_message

      t.timestamps
    end

    add_index :pwb_website_integrations, [:website_id, :category]
    add_index :pwb_website_integrations, [:website_id, :category, :provider], unique: true, name: 'idx_website_integrations_unique_provider'
    add_index :pwb_website_integrations, [:website_id, :enabled]
  end
end
