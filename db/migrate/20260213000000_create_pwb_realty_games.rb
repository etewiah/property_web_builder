# frozen_string_literal: true

class CreatePwbRealtyGames < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_realty_games, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.bigint   :website_id, null: false
      t.string   :slug, null: false
      t.string   :title, null: false
      t.text     :description
      t.string   :bg_image_url
      t.string   :default_currency, default: 'EUR', null: false
      t.string   :default_country
      t.boolean  :active, default: true, null: false
      t.boolean  :hidden_from_landing_page, default: false, null: false
      t.datetime :start_at
      t.datetime :end_at
      t.jsonb    :validation_rules, default: {}, null: false
      t.integer  :sessions_count, default: 0, null: false
      t.integer  :estimates_count, default: 0, null: false

      t.timestamps
    end

    add_index :pwb_realty_games, [:website_id, :slug], unique: true
    add_index :pwb_realty_games, [:website_id, :active]
    add_index :pwb_realty_games, :website_id

    add_foreign_key :pwb_realty_games, :pwb_websites, column: :website_id
  end
end
