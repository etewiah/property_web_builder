# frozen_string_literal: true

# Migration to add palette mode columns for dynamic/compiled color palette support
#
# palette_mode: Controls how palette CSS is rendered
#   - "dynamic" (default): CSS variables set at runtime from style_variables
#   - "compiled": Pre-generated CSS with baked-in hex values for maximum performance
#
# compiled_palette_css: Stores the pre-compiled CSS when in compiled mode
# palette_compiled_at: Timestamp of when the palette was compiled (for staleness detection)
#
class AddPaletteModeToPwbWebsites < ActiveRecord::Migration[7.2]
  def change
    add_column :pwb_websites, :palette_mode, :string, default: "dynamic", null: false
    add_column :pwb_websites, :compiled_palette_css, :text
    add_column :pwb_websites, :palette_compiled_at, :datetime

    add_index :pwb_websites, :palette_mode
  end
end
