class UpdateListedPropertiesToVersion4 < ActiveRecord::Migration[8.1]
  def change
    # Add SEO fields (seo_title, meta_description) from listings to the materialized view
    update_view :pwb_properties, version: 4, revert_to_version: 3, materialized: true
  end
end
