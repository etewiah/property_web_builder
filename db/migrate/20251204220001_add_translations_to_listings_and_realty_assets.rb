# frozen_string_literal: true

class AddTranslationsToListingsAndRealtyAssets < ActiveRecord::Migration[7.0]
  def change
    # SaleListing - translates :title, :description (listing marketing text)
    add_column :pwb_sale_listings, :translations, :jsonb, default: {}, null: false
    add_index :pwb_sale_listings, :translations, using: :gin

    # RentalListing - translates :title, :description (listing marketing text)
    add_column :pwb_rental_listings, :translations, :jsonb, default: {}, null: false
    add_index :pwb_rental_listings, :translations, using: :gin

    # RealtyAsset - translations column for future use
    add_column :pwb_realty_assets, :translations, :jsonb, default: {}, null: false
    add_index :pwb_realty_assets, :translations, using: :gin
  end
end
