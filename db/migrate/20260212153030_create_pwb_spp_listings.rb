# frozen_string_literal: true

class CreatePwbSppListings < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_spp_listings, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      # Core state (same pattern as pwb_sale_listings)
      t.boolean  :active,    default: false, null: false
      t.boolean  :visible,   default: false
      t.boolean  :archived,  default: false
      t.boolean  :noindex,   default: false, null: false

      # Relationship
      t.uuid     :realty_asset_id, null: false

      # Listing type — "sale" or "rental"
      t.string   :listing_type, null: false, default: "sale"

      # Price (independent from SaleListing/RentalListing)
      t.bigint   :price_cents,    default: 0, null: false
      t.string   :price_currency, default: "EUR", null: false

      # Curated content
      t.jsonb    :photo_ids_ordered,     default: []
      t.jsonb    :highlighted_features,  default: []

      # Translations (title, description, seo_title, meta_description via Mobility)
      t.jsonb    :translations, default: {}, null: false

      # SPP-specific fields
      t.string   :spp_slug
      t.string   :live_url
      t.string   :template
      t.jsonb    :spp_settings, default: {}
      t.jsonb    :extra_data,   default: {}
      t.datetime :published_at

      t.timestamps
    end

    add_index :pwb_spp_listings, :realty_asset_id
    add_index :pwb_spp_listings, [:realty_asset_id, :listing_type, :active],
              name: "index_pwb_spp_listings_unique_active",
              unique: true, where: "(active = true)"
    add_index :pwb_spp_listings, :spp_slug
    add_index :pwb_spp_listings, :noindex
    add_index :pwb_spp_listings, :translations, using: :gin

    add_foreign_key :pwb_spp_listings, :pwb_realty_assets,
                    column: :realty_asset_id, type: :uuid
  end
end
