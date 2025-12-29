# frozen_string_literal: true

# Add counter caches to improve performance by avoiding COUNT(*) queries.
#
# This migration adds:
# - realty_assets_count to pwb_websites (for website.realty_assets.count)
# - prop_photos_count to pwb_realty_assets (for property.prop_photos.count)
#
# These counters are automatically maintained by Rails' counter_cache option.
# Performance improvement: 10-50ms saved per dashboard/statistics page load.
#
class AddCounterCaches < ActiveRecord::Migration[8.1]
  def change
    # Counter cache for properties per website
    # Avoids: SELECT COUNT(*) FROM pwb_realty_assets WHERE website_id = ?
    add_column :pwb_websites, :realty_assets_count, :integer, default: 0, null: false

    # Counter cache for photos per property
    # Avoids: SELECT COUNT(*) FROM pwb_prop_photos WHERE realty_asset_id = ?
    add_column :pwb_realty_assets, :prop_photos_count, :integer, default: 0, null: false

    # Add indexes for efficient sorting by count
    add_index :pwb_websites, :realty_assets_count
    add_index :pwb_realty_assets, :prop_photos_count

    # Backfill existing counts
    reversible do |dir|
      dir.up do
        say_with_time "Backfilling realty_assets_count on pwb_websites" do
          execute <<-SQL.squish
            UPDATE pwb_websites
            SET realty_assets_count = (
              SELECT COUNT(*)
              FROM pwb_realty_assets
              WHERE pwb_realty_assets.website_id = pwb_websites.id
            )
          SQL
        end

        say_with_time "Backfilling prop_photos_count on pwb_realty_assets" do
          execute <<-SQL.squish
            UPDATE pwb_realty_assets
            SET prop_photos_count = (
              SELECT COUNT(*)
              FROM pwb_prop_photos
              WHERE pwb_prop_photos.realty_asset_id = pwb_realty_assets.id
            )
          SQL
        end
      end
    end
  end
end
