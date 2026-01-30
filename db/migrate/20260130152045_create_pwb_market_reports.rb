# frozen_string_literal: true

class CreatePwbMarketReports < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_market_reports do |t|
      # References
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :user, foreign_key: { to_table: :pwb_users }
      t.references :ai_generation_request, foreign_key: { to_table: :pwb_ai_generation_requests }
      t.uuid :subject_property_id

      # Report type and metadata
      t.string :report_type, null: false  # cma, market_report
      t.string :title, null: false
      t.string :reference_number
      t.string :status, default: 'draft'  # draft, generating, completed, shared

      # Location (for area-based reports without subject property)
      t.string :city
      t.string :region
      t.string :postal_code
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.decimal :radius_km, precision: 5, scale: 2

      # Data storage (JSONB for flexibility)
      t.jsonb :subject_details, default: {}
      t.jsonb :comparable_properties, default: []
      t.jsonb :market_statistics, default: {}
      t.jsonb :ai_insights, default: {}
      t.jsonb :branding, default: {}

      # Pricing recommendations
      t.integer :suggested_price_low_cents
      t.integer :suggested_price_high_cents
      t.string :suggested_price_currency, default: 'USD'

      # Sharing
      t.string :share_token
      t.datetime :generated_at
      t.datetime :shared_at
      t.integer :view_count, default: 0

      t.timestamps
    end

    # Indexes for common queries
    add_index :pwb_market_reports, [:website_id, :report_type]
    add_index :pwb_market_reports, :share_token, unique: true, where: "share_token IS NOT NULL"
    add_index :pwb_market_reports, :subject_property_id
    add_index :pwb_market_reports, :status

    # Foreign key for subject property (uuid reference to pwb_realty_assets)
    add_foreign_key :pwb_market_reports, :pwb_realty_assets, column: :subject_property_id
  end
end
