# frozen_string_literal: true

class AddGameFieldsToListings < ActiveRecord::Migration[7.0]
  def change
    # Add game fields to sale_listings
    add_column :pwb_sale_listings, :game_token, :string
    add_column :pwb_sale_listings, :game_enabled, :boolean, default: false
    add_column :pwb_sale_listings, :game_views_count, :integer, default: 0
    add_column :pwb_sale_listings, :game_shares_count, :integer, default: 0

    add_index :pwb_sale_listings, :game_token, unique: true, where: "game_token IS NOT NULL"

    # Add game fields to rental_listings
    add_column :pwb_rental_listings, :game_token, :string
    add_column :pwb_rental_listings, :game_enabled, :boolean, default: false
    add_column :pwb_rental_listings, :game_views_count, :integer, default: 0
    add_column :pwb_rental_listings, :game_shares_count, :integer, default: 0

    add_index :pwb_rental_listings, :game_token, unique: true, where: "game_token IS NOT NULL"
  end
end
