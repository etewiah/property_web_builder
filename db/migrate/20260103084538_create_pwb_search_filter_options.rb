# frozen_string_literal: true

class CreatePwbSearchFilterOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_search_filter_options do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      # Filter type: 'property_type', 'feature', 'amenity', 'location'
      t.string :filter_type, null: false

      # Unique identifier within the website and filter type
      t.string :global_key, null: false

      # External API code (e.g., "1-1" for Resales Online apartment)
      t.string :external_code

      # Multi-language labels stored as JSONB
      # Format: { "en": "Apartment", "es": "Apartamento", "fr": "Appartement" }
      t.jsonb :translations, null: false, default: {}

      # Visibility controls
      t.boolean :visible, null: false, default: true
      t.boolean :show_in_search, null: false, default: true

      # Display order
      t.integer :sort_order, null: false, default: 0

      # Parent ID for hierarchical types (e.g., "Villa" > "Detached Villa")
      t.references :parent, foreign_key: { to_table: :pwb_search_filter_options }

      # Optional icon class (e.g., "fa-building", "pool", "parking")
      t.string :icon

      # Provider-specific configuration and external mappings
      # Format: {
      #   "external_mappings": { "resales_online": "1-1", "other_provider": "APT" },
      #   "category": "residential",
      #   "param_name": "p_Pool"  # for features
      # }
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    # Ensure unique global_key per website and filter_type
    add_index :pwb_search_filter_options,
              [:website_id, :filter_type, :global_key],
              unique: true,
              name: 'index_search_filter_options_unique_key'

    # Fast lookups by filter type
    add_index :pwb_search_filter_options,
              [:website_id, :filter_type],
              name: 'index_search_filter_options_on_type'

    # Fast lookups by external code for provider mapping
    add_index :pwb_search_filter_options,
              [:website_id, :external_code],
              where: 'external_code IS NOT NULL',
              name: 'index_search_filter_options_on_external_code'

    # Ordering index for sorted queries
    add_index :pwb_search_filter_options,
              [:website_id, :filter_type, :sort_order],
              name: 'index_search_filter_options_on_order'
  end
end
