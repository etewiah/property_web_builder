# frozen_string_literal: true

# Adds a unified search_config column to websites for configuring property search filters.
# This configuration is source-agnostic and works for both internal listings and external feeds.
#
# The search_config JSON structure supports:
# - filters: Configuration for each filter (price, bedrooms, bathrooms, area, etc.)
#   - enabled: boolean - Whether the filter is displayed
#   - position: integer - Display order (0 = first)
#   - input_type: string - "dropdown", "manual", "dropdown_with_manual", "checkbox", "text"
#   - For price filters, separate configs for "sale" and "rental" listing types
# - display: Global display settings (show_results_map, default_sort, etc.)
# - listing_types: Configuration for sale/rental listing types
#
# See docs/architecture/SEARCH_OPTIONS_STRATEGY.md for full documentation.
class AddSearchConfigToWebsites < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_websites, :search_config, :jsonb, default: {}, null: false

    # GIN index for efficient JSON queries
    add_index :pwb_websites, :search_config, using: :gin
  end
end
