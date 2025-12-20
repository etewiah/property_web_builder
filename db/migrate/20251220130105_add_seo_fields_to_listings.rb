class AddSeoFieldsToListings < ActiveRecord::Migration[8.1]
  def change
    # Add SEO fields to sale listings
    add_column :pwb_sale_listings, :seo_title, :string
    add_column :pwb_sale_listings, :meta_description, :text

    # Add SEO fields to rental listings
    add_column :pwb_rental_listings, :seo_title, :string
    add_column :pwb_rental_listings, :meta_description, :text
  end
end
