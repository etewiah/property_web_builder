class AddActiveToListings < ActiveRecord::Migration[8.0]
  def change
    # Add active field to sale_listings - only one can be active per realty_asset
    add_column :pwb_sale_listings, :active, :boolean, default: false, null: false
    add_index :pwb_sale_listings, [:realty_asset_id, :active],
              unique: true,
              where: "active = true",
              name: "index_pwb_sale_listings_unique_active"

    # Add active field to rental_listings - only one can be active per realty_asset
    add_column :pwb_rental_listings, :active, :boolean, default: false, null: false
    add_index :pwb_rental_listings, [:realty_asset_id, :active],
              unique: true,
              where: "active = true",
              name: "index_pwb_rental_listings_unique_active"

    # Set existing visible, non-archived listings as active
    # This ensures backward compatibility with existing data
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE pwb_sale_listings
          SET active = true
          WHERE visible = true AND archived = false
          AND id = (
            SELECT id FROM pwb_sale_listings sl2
            WHERE sl2.realty_asset_id = pwb_sale_listings.realty_asset_id
            AND sl2.visible = true AND sl2.archived = false
            ORDER BY sl2.created_at DESC
            LIMIT 1
          )
        SQL

        execute <<-SQL
          UPDATE pwb_rental_listings
          SET active = true
          WHERE visible = true AND archived = false
          AND id = (
            SELECT id FROM pwb_rental_listings rl2
            WHERE rl2.realty_asset_id = pwb_rental_listings.realty_asset_id
            AND rl2.visible = true AND rl2.archived = false
            ORDER BY rl2.created_at DESC
            LIMIT 1
          )
        SQL
      end
    end
  end
end
