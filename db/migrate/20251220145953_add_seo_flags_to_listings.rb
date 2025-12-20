class AddSeoFlagsToListings < ActiveRecord::Migration[8.1]
  def change
    # Add noindex field to sale listings (default false - index by default)
    # Set noindex=true for archived or reserved listings
    add_column :pwb_sale_listings, :noindex, :boolean, default: false, null: false

    # Add noindex field to rental listings
    add_column :pwb_rental_listings, :noindex, :boolean, default: false, null: false

    # Index for efficient filtering
    add_index :pwb_sale_listings, :noindex
    add_index :pwb_rental_listings, :noindex
  end
end
