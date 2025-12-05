class UpdatePwbPropertiesToVersion2 < ActiveRecord::Migration[8.0]
  def change
    # pwb_properties is a materialized view, so we need to drop and recreate it
    drop_view :pwb_properties, materialized: true, revert_to_version: 1

    create_view :pwb_properties, materialized: true, version: 2

    # Re-add indexes that were dropped with the materialized view
    add_index :pwb_properties, :id, unique: true, name: 'index_pwb_properties_on_id'
    add_index :pwb_properties, :website_id, name: 'index_pwb_properties_on_website_id'
    add_index :pwb_properties, :visible, name: 'index_pwb_properties_on_visible'
    add_index :pwb_properties, :for_sale, name: 'index_pwb_properties_on_for_sale'
    add_index :pwb_properties, :for_rent, name: 'index_pwb_properties_on_for_rent'
    add_index :pwb_properties, :highlighted, name: 'index_pwb_properties_on_highlighted'
    add_index :pwb_properties, :reference, name: 'index_pwb_properties_on_reference'
    add_index :pwb_properties, :price_sale_current_cents, name: 'index_pwb_properties_on_price_sale_cents'
    add_index :pwb_properties, :price_rental_monthly_current_cents, name: 'index_pwb_properties_on_price_rental_cents'
    add_index :pwb_properties, [:latitude, :longitude], name: 'index_pwb_properties_on_lat_lng'
    add_index :pwb_properties, :count_bedrooms, name: 'index_pwb_properties_on_bedrooms'
    add_index :pwb_properties, :count_bathrooms, name: 'index_pwb_properties_on_bathrooms'
    add_index :pwb_properties, :prop_type_key, name: 'index_pwb_properties_on_prop_type'
  end
end
