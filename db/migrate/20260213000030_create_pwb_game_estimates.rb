# frozen_string_literal: true

class CreatePwbGameEstimates < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_game_estimates, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid     :game_session_id, null: false
      t.uuid     :game_listing_id, null: false
      t.bigint   :website_id, null: false
      t.bigint   :estimated_price_cents, null: false
      t.bigint   :actual_price_cents, null: false
      t.string   :currency, default: 'EUR', null: false
      t.decimal  :percentage_diff, precision: 8, scale: 2
      t.integer  :score, default: 0, null: false
      t.integer  :property_index
      t.jsonb    :estimate_details, default: {}, null: false

      t.timestamps
    end

    add_index :pwb_game_estimates, [:game_session_id, :game_listing_id], unique: true,
              name: 'index_pwb_game_estimates_unique_session_listing'
    add_index :pwb_game_estimates, :game_session_id
    add_index :pwb_game_estimates, :game_listing_id
    add_index :pwb_game_estimates, :website_id

    add_foreign_key :pwb_game_estimates, :pwb_game_sessions,
                    column: :game_session_id, type: :uuid
    add_foreign_key :pwb_game_estimates, :pwb_game_listings,
                    column: :game_listing_id, type: :uuid
    add_foreign_key :pwb_game_estimates, :pwb_websites, column: :website_id
  end
end
