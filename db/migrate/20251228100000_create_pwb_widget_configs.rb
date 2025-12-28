# frozen_string_literal: true

class CreatePwbWidgetConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_widget_configs, id: :uuid do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.string :name, null: false
      t.string :widget_key, null: false # Unique public identifier for embedding
      t.boolean :active, default: true, null: false

      # Display settings
      t.string :layout, default: 'grid' # grid, list, carousel
      t.integer :columns, default: 3 # For grid layout
      t.integer :max_properties, default: 12 # Limit properties shown
      t.boolean :show_search, default: false
      t.boolean :show_filters, default: false
      t.boolean :show_pagination, default: true

      # Property filters (which properties to include)
      t.string :listing_type # 'sale', 'rent', or nil for both
      t.string :property_types, array: true, default: [] # Filter by prop_type_key
      t.integer :min_price_cents
      t.integer :max_price_cents
      t.integer :min_bedrooms
      t.integer :max_bedrooms
      t.boolean :highlighted_only, default: false

      # Styling
      t.jsonb :theme, default: {} # Colors, fonts, etc.
      # Example theme structure:
      # {
      #   "primary_color": "#3B82F6",
      #   "secondary_color": "#1E40AF",
      #   "text_color": "#1F2937",
      #   "background_color": "#FFFFFF",
      #   "card_background": "#F9FAFB",
      #   "border_radius": "8px",
      #   "font_family": "system-ui, sans-serif"
      # }

      # Display field toggles
      t.jsonb :visible_fields, default: {} # Which fields to show
      # Example:
      # {
      #   "price": true,
      #   "bedrooms": true,
      #   "bathrooms": true,
      #   "area": true,
      #   "location": true,
      #   "reference": false
      # }

      # Allowed domains (for CORS and referrer validation)
      t.string :allowed_domains, array: true, default: []

      # Analytics
      t.integer :impressions_count, default: 0
      t.integer :clicks_count, default: 0

      t.timestamps
    end

    add_index :pwb_widget_configs, :widget_key, unique: true
    add_index :pwb_widget_configs, [:website_id, :active]
  end
end
