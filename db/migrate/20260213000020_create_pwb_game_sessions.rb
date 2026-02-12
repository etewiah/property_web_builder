# frozen_string_literal: true

class CreatePwbGameSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_game_sessions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid     :realty_game_id, null: false
      t.bigint   :website_id, null: false
      t.string   :guest_name
      t.string   :visitor_token, null: false
      t.string   :user_uuid
      t.integer  :total_score, default: 0, null: false
      t.string   :performance_rating

      t.timestamps
    end

    add_index :pwb_game_sessions, [:realty_game_id, :visitor_token],
              name: 'index_pwb_game_sessions_on_game_and_visitor'
    add_index :pwb_game_sessions, [:website_id, :total_score],
              name: 'index_pwb_game_sessions_on_website_and_score'
    add_index :pwb_game_sessions, :realty_game_id
    add_index :pwb_game_sessions, :website_id

    add_foreign_key :pwb_game_sessions, :pwb_realty_games,
                    column: :realty_game_id, type: :uuid
    add_foreign_key :pwb_game_sessions, :pwb_websites, column: :website_id
  end
end
