class AddSlugIndexToPwbProperties < ActiveRecord::Migration[8.0]
  def change
    # Add index on slug column for fast lookups in materialized view
    add_index :pwb_properties, :slug, name: 'index_pwb_properties_on_slug'
  end
end
