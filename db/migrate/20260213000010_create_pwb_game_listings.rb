# frozen_string_literal: true

class CreatePwbGameListings < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_game_listings, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid     :realty_game_id, null: false
      t.uuid     :realty_asset_id, null: false
      t.boolean  :visible, default: true, null: false
      t.integer  :sort_order, default: 0, null: false
      t.string   :display_title
      t.jsonb    :extra_data, default: {}, null: false

      t.timestamps
    end

    add_index :pwb_game_listings, [:realty_game_id, :realty_asset_id], unique: true,
              name: 'index_pwb_game_listings_unique_game_asset'
    add_index :pwb_game_listings, :realty_game_id
    add_index :pwb_game_listings, :realty_asset_id

    add_foreign_key :pwb_game_listings, :pwb_realty_games,
                    column: :realty_game_id, type: :uuid
    add_foreign_key :pwb_game_listings, :pwb_realty_assets,
                    column: :realty_asset_id, type: :uuid
  end
end
