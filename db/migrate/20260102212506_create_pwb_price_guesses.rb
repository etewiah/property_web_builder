# frozen_string_literal: true

class CreatePwbPriceGuesses < ActiveRecord::Migration[7.0]
  def change
    create_table :pwb_price_guesses, id: :uuid do |t|
      # Polymorphic reference to either SaleListing or RentalListing
      t.references :listing, polymorphic: true, type: :uuid, null: false

      # Website for multi-tenancy (integer ID)
      t.references :website, foreign_key: { to_table: :pwb_websites }, null: false

      # Anonymous visitor identification (stored in browser localStorage)
      t.string :visitor_token, null: false

      # The guess
      t.bigint :guessed_price_cents, null: false
      t.string :guessed_price_currency, default: "EUR"

      # Snapshot of actual price at time of guess (for historical accuracy)
      t.bigint :actual_price_cents, null: false
      t.string :actual_price_currency, default: "EUR"

      # Score calculation results
      t.decimal :percentage_diff, precision: 8, scale: 2
      t.integer :score, default: 0

      t.timestamps
    end

    # Ensure one guess per visitor per listing
    add_index :pwb_price_guesses, %i[listing_type listing_id visitor_token],
              unique: true,
              name: "index_price_guesses_on_listing_and_visitor"

    # For leaderboard queries
    add_index :pwb_price_guesses, %i[listing_type listing_id score],
              name: "index_price_guesses_on_listing_and_score"
  end
end
