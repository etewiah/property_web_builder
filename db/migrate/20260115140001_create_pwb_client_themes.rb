# frozen_string_literal: true

# Creates the pwb_client_themes table for Astro A themes
# These are database-backed themes used by client-rendered websites
class CreatePwbClientThemes < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_client_themes do |t|
      # Theme identifier (lowercase, e.g., 'amsterdam')
      t.string :name, null: false

      # Human-readable name (e.g., 'Amsterdam Modern')
      t.string :friendly_name, null: false

      # Semantic version
      t.string :version, default: '1.0.0'

      # Description for admin UI
      t.text :description

      # Preview image URL for theme selection
      t.string :preview_image_url

      # Default configuration values
      t.jsonb :default_config, default: {}

      # Schema for color customization options
      t.jsonb :color_schema, default: {}

      # Schema for font customization options
      t.jsonb :font_schema, default: {}

      # Schema for layout customization options
      t.jsonb :layout_options, default: {}

      # Whether this theme is available for selection
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    # Unique constraint on name
    add_index :pwb_client_themes, :name, unique: true

    # Index for filtering enabled themes
    add_index :pwb_client_themes, :enabled
  end
end
