# frozen_string_literal: true

# Migration to add rendering mode support to websites
# This enables websites to choose between Rails (B themes) and Client (A themes) rendering
class AddRenderingModeToWebsites < ActiveRecord::Migration[8.0]
  def change
    # Rendering mode: 'rails' for traditional server-side rendering, 'client' for Astro
    add_column :pwb_websites, :rendering_mode, :string, default: 'rails', null: false

    # Client theme name (only used when rendering_mode = 'client')
    add_column :pwb_websites, :client_theme_name, :string

    # Website-specific client theme configuration overrides
    add_column :pwb_websites, :client_theme_config, :jsonb, default: {}

    # Index for filtering by rendering mode
    add_index :pwb_websites, :rendering_mode

    # Check constraint to ensure only valid values
    add_check_constraint :pwb_websites,
                         "rendering_mode IN ('rails', 'client')",
                         name: 'rendering_mode_valid'
  end
end
