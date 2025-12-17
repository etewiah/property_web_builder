# frozen_string_literal: true

class CreateAhoyVisitsAndEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :ahoy_visits do |t|
      t.string :visit_token
      t.string :visitor_token

      # Multi-tenant scope - each visit belongs to a website
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      # User (optional - for logged-in visitors)
      t.references :user, foreign_key: { to_table: :pwb_users }

      # Traffic source
      t.text :referrer
      t.string :referring_domain
      t.text :landing_page

      # UTM parameters
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :utm_term
      t.string :utm_content

      # Technology
      t.string :browser
      t.string :os
      t.string :device_type

      # Location (from IP geocoding)
      t.string :country
      t.string :region
      t.string :city

      t.timestamp :started_at
    end

    add_index :ahoy_visits, :visit_token, unique: true
    add_index :ahoy_visits, [:website_id, :started_at]
    add_index :ahoy_visits, :visitor_token

    create_table :ahoy_events do |t|
      t.references :visit, foreign_key: { to_table: :ahoy_visits }

      # Multi-tenant scope - denormalized for query performance
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      # Event data
      t.string :name, null: false
      t.jsonb :properties, default: {}

      t.timestamp :time, null: false
    end

    add_index :ahoy_events, [:website_id, :time]
    add_index :ahoy_events, [:website_id, :name, :time]
    add_index :ahoy_events, :properties, using: :gin
  end
end
