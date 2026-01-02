# Search Options Configuration Strategy

## Executive Summary

This document outlines a comprehensive strategy for managing search filter options (price ranges, bedroom/bathroom counts, area ranges, etc.) for **all property listings** - both internal and external. Search configuration is a core website feature, independent of whether the website uses external feeds or internal property management.

### Design Principles

1. **Source-agnostic** - Same search configuration works for internal listings and external feeds
2. **Fully configurable** - Admins control every aspect: visibility, order, defaults, input types
3. **Per-website isolation** - Each website has independent configuration
4. **Seed-friendly** - Easy to populate via seed packs
5. **Extensively tested** - Full test coverage with detailed documentation

---

## Current State Analysis

### Problems with Current Approach

1. **No default values** - Min/max price fields are empty, requiring user to enter values
2. **Hardcoded ranges** - Bedroom (1-6) and bathroom (1-4) ranges can't be customized
3. **No price presets** - No suggested price ranges
4. **No per-website customization** - All websites use same static values
5. **No input type choice** - Can't choose between dropdowns, manual entry, or both
6. **No filter ordering** - Can't rearrange filter display order
7. **No map toggle** - Can't configure whether search results map is shown
8. **Tied to external feeds** - Filter options only exist in ExternalFeed::Manager

### Existing Infrastructure to Leverage

| Component | How It Helps |
|-----------|--------------|
| Website model JSON columns | Pattern for flexible configuration |
| Site Admin tabs pattern | Add new "Search Configuration" tab |
| SeedPack system | Add search_config to pack YAML files |
| I18n translations | Already set up for filter labels |

---

## Proposed Solution

### 1. Data Model

#### New `search_config` JSON Column on Website

A dedicated column for search configuration, separate from external feed settings.

**Migration:**

```ruby
class AddSearchConfigToWebsites < ActiveRecord::Migration[7.0]
  def change
    add_column :pwb_websites, :search_config, :jsonb, default: {}, null: false
    add_index :pwb_websites, :search_config, using: :gin
  end
end
```

**Complete Configuration Schema:**

```json
{
  "filters": {
    "price": {
      "enabled": true,
      "position": 1,
      "input_type": "dropdown_with_manual",
      "sale": {
        "min": 50000,
        "max": 5000000,
        "default_min": null,
        "default_max": null,
        "step": 50000,
        "presets": [50000, 100000, 200000, 350000, 500000, 750000, 1000000, 1500000, 2000000, 3000000, 5000000]
      },
      "rental": {
        "min": 200,
        "max": 15000,
        "default_min": null,
        "default_max": null,
        "step": 100,
        "presets": [200, 500, 750, 1000, 1500, 2000, 2500, 3000, 5000, 7500, 10000, 15000]
      }
    },
    "bedrooms": {
      "enabled": true,
      "position": 2,
      "input_type": "dropdown",
      "min": 0,
      "max": 10,
      "default_min": null,
      "default_max": null,
      "options": ["Any", 1, 2, 3, 4, 5, "6+"],
      "show_max_filter": false
    },
    "bathrooms": {
      "enabled": true,
      "position": 3,
      "input_type": "dropdown",
      "min": 0,
      "max": 8,
      "default_min": null,
      "default_max": null,
      "options": ["Any", 1, 2, 3, 4, "5+"],
      "show_max_filter": false
    },
    "area": {
      "enabled": true,
      "position": 4,
      "input_type": "dropdown_with_manual",
      "unit": "sqm",
      "min": 0,
      "max": 2000,
      "default_min": null,
      "default_max": null,
      "step": 25,
      "presets": [50, 75, 100, 150, 200, 300, 500, 750, 1000, 1500, 2000]
    },
    "property_type": {
      "enabled": true,
      "position": 5,
      "input_type": "checkbox",
      "allow_multiple": true
    },
    "location": {
      "enabled": true,
      "position": 6,
      "input_type": "dropdown",
      "allow_multiple": false
    },
    "features": {
      "enabled": false,
      "position": 7,
      "input_type": "checkbox",
      "allow_multiple": true
    },
    "reference": {
      "enabled": true,
      "position": 0,
      "input_type": "text"
    }
  },
  "display": {
    "show_results_map": true,
    "map_default_expanded": false,
    "results_per_page_options": [12, 24, 48],
    "default_results_per_page": 24,
    "default_sort": "newest",
    "sort_options": ["price_asc", "price_desc", "newest", "updated"],
    "show_save_search": true,
    "show_favorites": true,
    "card_layout": "grid",
    "show_active_filters": true
  },
  "listing_types": {
    "sale": {
      "enabled": true,
      "label_key": "forSale",
      "is_default": true
    },
    "rental": {
      "enabled": true,
      "label_key": "forRent",
      "is_default": false
    }
  }
}
```

### Configuration Schema Details

#### Input Types

| Type | Description | Use Case |
|------|-------------|----------|
| `dropdown` | Select from predefined options only | Bedrooms, bathrooms, location |
| `manual` | Free text/number input only | Reference search |
| `dropdown_with_manual` | Dropdown presets + manual entry option | Price, area |
| `checkbox` | Multiple selection checkboxes | Property type, features |
| `radio` | Single selection radio buttons | Listing type |
| `text` | Free text input | Reference/keyword search |

#### Filter Configuration Fields

| Field | Type | Description |
|-------|------|-------------|
| `enabled` | boolean | Whether filter is shown |
| `position` | integer | Display order (0 = first) |
| `input_type` | string | How the filter is rendered |
| `min` / `max` | number | Allowed value range |
| `default_min` / `default_max` | number/null | Pre-populated defaults |
| `step` | number | Increment for manual input |
| `presets` | array | Dropdown options |
| `options` | array | Custom option labels |
| `show_max_filter` | boolean | Show separate max filter |
| `allow_multiple` | boolean | Multi-select allowed |

---

### 2. Service Layer

#### New Class: `Pwb::SearchConfig`

Central service for accessing search configuration with sensible defaults.

```ruby
# app/services/pwb/search_config.rb
module Pwb
  class SearchConfig
    # Comprehensive defaults - used when website has no custom config
    DEFAULT_CONFIG = {
      filters: {
        reference: { enabled: true, position: 0, input_type: "text" },
        price: {
          enabled: true, position: 1, input_type: "dropdown_with_manual",
          sale: { min: 0, max: 10_000_000, step: 50_000, presets: default_sale_presets },
          rental: { min: 0, max: 20_000, step: 100, presets: default_rental_presets }
        },
        bedrooms: {
          enabled: true, position: 2, input_type: "dropdown",
          min: 0, max: 10, options: ["Any", 1, 2, 3, 4, 5, "6+"]
        },
        bathrooms: {
          enabled: true, position: 3, input_type: "dropdown",
          min: 0, max: 8, options: ["Any", 1, 2, 3, 4, "5+"]
        },
        area: {
          enabled: true, position: 4, input_type: "dropdown_with_manual",
          unit: "sqm", min: 0, max: 5000, step: 25, presets: default_area_presets
        },
        property_type: { enabled: true, position: 5, input_type: "checkbox", allow_multiple: true },
        location: { enabled: true, position: 6, input_type: "dropdown", allow_multiple: false },
        features: { enabled: false, position: 7, input_type: "checkbox", allow_multiple: true }
      },
      display: {
        show_results_map: false,
        map_default_expanded: false,
        results_per_page_options: [12, 24, 48],
        default_results_per_page: 24,
        default_sort: "newest",
        sort_options: %w[price_asc price_desc newest updated],
        show_save_search: true,
        show_favorites: true,
        card_layout: "grid",
        show_active_filters: true
      },
      listing_types: {
        sale: { enabled: true, is_default: true },
        rental: { enabled: true, is_default: false }
      }
    }.deep_freeze

    attr_reader :website, :listing_type

    def initialize(website, listing_type: nil)
      @website = website
      @listing_type = (listing_type || default_listing_type).to_sym
    end

    # Main configuration accessor - merges website config with defaults
    def config
      @config ||= deep_merge_config(DEFAULT_CONFIG, website_config)
    end

    # Get all enabled filters in display order
    def enabled_filters
      config[:filters]
        .select { |_, cfg| cfg[:enabled] }
        .sort_by { |_, cfg| cfg[:position] }
        .map { |key, cfg| [key, cfg] }
    end

    # Get specific filter configuration
    def filter(name)
      config.dig(:filters, name.to_sym)
    end

    # Price configuration for current listing type
    def price_config
      filter(:price)&.dig(listing_type) || filter(:price)&.dig(:sale)
    end

    def price_presets
      price_config&.dig(:presets) || []
    end

    def price_input_type
      filter(:price)&.dig(:input_type) || "dropdown_with_manual"
    end

    def bedroom_options
      filter(:bedrooms)&.dig(:options) || ["Any", 1, 2, 3, 4, 5, "6+"]
    end

    def bathroom_options
      filter(:bathrooms)&.dig(:options) || ["Any", 1, 2, 3, 4, "5+"]
    end

    def area_presets
      filter(:area)&.dig(:presets) || []
    end

    def area_unit
      filter(:area)&.dig(:unit) || "sqm"
    end

    # Display configuration
    def show_map?
      config.dig(:display, :show_results_map) || false
    end

    def default_sort
      config.dig(:display, :default_sort) || "newest"
    end

    def results_per_page_options
      config.dig(:display, :results_per_page_options) || [12, 24, 48]
    end

    def default_results_per_page
      config.dig(:display, :default_results_per_page) || 24
    end

    def show_active_filters?
      config.dig(:display, :show_active_filters) != false
    end

    def show_save_search?
      config.dig(:display, :show_save_search) != false
    end

    def show_favorites?
      config.dig(:display, :show_favorites) != false
    end

    # Listing type helpers
    def enabled_listing_types
      config[:listing_types]
        .select { |_, cfg| cfg[:enabled] }
        .keys
    end

    def default_listing_type
      config[:listing_types]
        .find { |_, cfg| cfg[:is_default] }
        &.first || :sale
    end

    # Generate filter options hash for views
    def filter_options_for_view
      {
        filters: enabled_filters.to_h,
        price: price_config,
        price_presets: price_presets,
        price_input_type: price_input_type,
        bedroom_options: bedroom_options,
        bathroom_options: bathroom_options,
        area_presets: area_presets,
        area_unit: area_unit,
        listing_types: enabled_listing_types,
        sort_options: sort_options_for_view,
        display: config[:display]
      }
    end

    private

    def website_config
      (website.search_config || {}).deep_symbolize_keys
    end

    def deep_merge_config(default, custom)
      default.deep_merge(custom) do |key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge_config(old_val, new_val)
        else
          new_val.nil? ? old_val : new_val
        end
      end
    end

    def sort_options_for_view
      config.dig(:display, :sort_options)&.map do |opt|
        { value: opt, label: I18n.t("search.sort.#{opt}", default: opt.titleize) }
      end
    end

    class << self
      def default_sale_presets
        [50_000, 100_000, 150_000, 200_000, 300_000, 400_000, 500_000,
         750_000, 1_000_000, 1_500_000, 2_000_000, 3_000_000, 5_000_000]
      end

      def default_rental_presets
        [250, 500, 750, 1_000, 1_250, 1_500, 2_000, 2_500, 3_000, 4_000, 5_000, 7_500, 10_000]
      end

      def default_area_presets
        [25, 50, 75, 100, 150, 200, 300, 400, 500, 750, 1_000, 1_500, 2_000]
      end
    end
  end
end
```

#### Website Model Integration

```ruby
# app/models/pwb/website.rb
class Website < ApplicationRecord
  # ... existing code ...

  # Search configuration accessor
  def search_configuration
    @search_configuration ||= Pwb::SearchConfig.new(self)
  end

  def search_configuration_for(listing_type)
    Pwb::SearchConfig.new(self, listing_type: listing_type)
  end

  # Helper to update specific search config keys
  def update_search_config(updates)
    current = search_config || {}
    self.search_config = current.deep_merge(updates.deep_stringify_keys)
    save
  end
end
```

---

### 3. Admin Interface

#### New Tab: "Search Configuration" in Site Admin

**Location:** New tab in `SiteAdmin::Website::SettingsController`

**Route:** `/site_admin/settings?tab=search`

#### Admin Form Design

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Search Configuration                                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│ ┌─ DISPLAY OPTIONS ───────────────────────────────────────────────────────┐ │
│ │                                                                          │ │
│ │ ☑ Show search results map       ☐ Map expanded by default               │ │
│ │ ☑ Show active filter chips      ☑ Show "Save Search" button             │ │
│ │ ☑ Show favorites button                                                  │ │
│ │                                                                          │ │
│ │ Default Sort: [Newest First          ▼]                                  │ │
│ │ Results Per Page: [12] [24] [48]  Default: [24 ▼]                        │ │
│ │                                                                          │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ ┌─ LISTING TYPES ─────────────────────────────────────────────────────────┐ │
│ │                                                                          │ │
│ │ ☑ Sale (For Sale)     ◉ Default                                         │ │
│ │ ☑ Rental (For Rent)   ○ Default                                         │ │
│ │                                                                          │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ ┌─ FILTERS ───────────────────────────────────────────────────────────────┐ │
│ │                                                                          │ │
│ │ Drag to reorder • Click to configure                                     │ │
│ │                                                                          │ │
│ │ ┌─────────────────────────────────────────────────────────────────────┐ │ │
│ │ │ ≡ ☑ Reference Search                              [Configure ▼]     │ │ │
│ │ └─────────────────────────────────────────────────────────────────────┘ │ │
│ │ ┌─────────────────────────────────────────────────────────────────────┐ │ │
│ │ │ ≡ ☑ Price Range                                   [Configure ▼]     │ │ │
│ │ │   ┌─ Price Configuration (expanded) ──────────────────────────────┐ │ │ │
│ │ │   │ Input Type: ○ Dropdown only                                   │ │ │ │
│ │ │   │             ○ Manual entry only                               │ │ │ │
│ │ │   │             ◉ Dropdown with manual entry                      │ │ │ │
│ │ │   │                                                               │ │ │ │
│ │ │   │ ── For Sale ──                                                │ │ │ │
│ │ │   │ Min: [0        ] Max: [10,000,000] Step: [50,000  ]           │ │ │ │
│ │ │   │ Default Min: [         ] Default Max: [         ]             │ │ │ │
│ │ │   │ Presets: [50000, 100000, 200000, 500000, 1000000, ...]        │ │ │ │
│ │ │   │                                                               │ │ │ │
│ │ │   │ ── For Rent ──                                                │ │ │ │
│ │ │   │ Min: [0        ] Max: [20,000    ] Step: [100     ]           │ │ │ │
│ │ │   │ Default Min: [         ] Default Max: [         ]             │ │ │ │
│ │ │   │ Presets: [500, 1000, 1500, 2000, 3000, 5000, ...]             │ │ │ │
│ │ │   └───────────────────────────────────────────────────────────────┘ │ │ │
│ │ └─────────────────────────────────────────────────────────────────────┘ │ │
│ │ ┌─────────────────────────────────────────────────────────────────────┐ │ │
│ │ │ ≡ ☑ Bedrooms                                      [Configure ▼]     │ │ │
│ │ │   Input Type: [Dropdown ▼]                                          │ │ │
│ │ │   Options: [Any, 1, 2, 3, 4, 5, 6+]                                 │ │ │
│ │ │   ☐ Show separate max filter                                        │ │ │
│ │ └─────────────────────────────────────────────────────────────────────┘ │ │
│ │ ┌─────────────────────────────────────────────────────────────────────┐ │ │
│ │ │ ≡ ☑ Bathrooms                                     [Configure ▼]     │ │ │
│ │ └─────────────────────────────────────────────────────────────────────┘ │ │
│ │ ┌─────────────────────────────────────────────────────────────────────┐ │ │
│ │ │ ≡ ☑ Area                                          [Configure ▼]     │ │ │
│ │ │   Unit: [Square Meters (m²) ▼]                                      │ │ │
│ │ │   Presets: [50, 100, 150, 200, 300, 500, 1000]                      │ │ │
│ │ └─────────────────────────────────────────────────────────────────────┘ │ │
│ │ ┌─────────────────────────────────────────────────────────────────────┐ │ │
│ │ │ ≡ ☑ Property Type                                 [Configure ▼]     │ │ │
│ │ └─────────────────────────────────────────────────────────────────────┘ │ │
│ │ ┌─────────────────────────────────────────────────────────────────────┐ │ │
│ │ │ ≡ ☑ Location                                      [Configure ▼]     │ │ │
│ │ └─────────────────────────────────────────────────────────────────────┘ │ │
│ │ ┌─────────────────────────────────────────────────────────────────────┐ │ │
│ │ │ ≡ ☐ Features                                      [Configure ▼]     │ │ │
│ │ └─────────────────────────────────────────────────────────────────────┘ │ │
│ │                                                                          │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│                                    [Reset to Defaults]  [Save Configuration] │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Controller Updates

```ruby
# app/controllers/pwb/site_admin/website/settings_controller.rb

# Add to TABS constant
TABS = %w[general appearance navigation home notifications seo social search].freeze

# Add case for search tab
def update
  case @tab
  when "search"
    update_search_config
  # ... existing cases
  end
end

private

def update_search_config
  if @website.update(search_config_params)
    flash[:notice] = t("site_admin.settings.search_updated")
    redirect_to site_admin_settings_path(tab: "search")
  else
    render :show
  end
end

def search_config_params
  # Build nested hash from form params
  params.require(:website).permit(
    search_config: {
      filters: {},  # Allow nested hash
      display: {},
      listing_types: {}
    }
  )
end
```

---

### 4. Seed Data Integration

#### Seed Pack YAML Format

```yaml
# db/seeds/packs/spain_coastal/config.yml
website:
  theme_name: luxe
  supported_locales: [es, en]
  default_currency: EUR

  search_config:
    filters:
      reference:
        enabled: true
        position: 0
      price:
        enabled: true
        position: 1
        input_type: dropdown_with_manual
        sale:
          min: 100000
          max: 5000000
          step: 50000
          default_min: 200000
          presets: [100000, 200000, 350000, 500000, 750000, 1000000, 1500000, 2000000, 3000000, 5000000]
        rental:
          min: 500
          max: 10000
          step: 250
          presets: [500, 750, 1000, 1500, 2000, 3000, 5000, 7500, 10000]
      bedrooms:
        enabled: true
        position: 2
        options: ["Any", 1, 2, 3, 4, 5, "6+"]
      bathrooms:
        enabled: true
        position: 3
        options: ["Any", 1, 2, 3, 4, "5+"]
      area:
        enabled: true
        position: 4
        unit: sqm
        presets: [50, 100, 150, 200, 300, 500, 750, 1000]
      property_type:
        enabled: true
        position: 5
      location:
        enabled: true
        position: 6
      features:
        enabled: false

    display:
      show_results_map: true
      map_default_expanded: false
      default_results_per_page: 24
      default_sort: price_asc
      show_active_filters: true
      show_save_search: true
      show_favorites: true

    listing_types:
      sale:
        enabled: true
        is_default: true
      rental:
        enabled: true
```

#### SeedPack Class Update

```ruby
# lib/pwb/seed_pack.rb

def apply_website_config
  # ... existing code ...

  # Apply search configuration
  if pack_config.dig("website", "search_config")
    apply_search_config
  end
end

def apply_search_config
  search_config = pack_config.dig("website", "search_config")
  return unless search_config

  website.update!(search_config: search_config)
  log_info "Applied search configuration"
end
```

---

### 5. View Layer Updates

#### Unified Search Form Helper

```ruby
# app/helpers/pwb/search_form_helper.rb
module Pwb
  module SearchFormHelper
    def search_config
      @search_config ||= current_website.search_configuration_for(current_listing_type)
    end

    def render_filter(filter_key, config)
      case config[:input_type]
      when "dropdown"
        render_dropdown_filter(filter_key, config)
      when "manual"
        render_manual_filter(filter_key, config)
      when "dropdown_with_manual"
        render_hybrid_filter(filter_key, config)
      when "checkbox"
        render_checkbox_filter(filter_key, config)
      when "text"
        render_text_filter(filter_key, config)
      end
    end

    def price_filter_options
      presets = search_config.price_presets
      currency = current_website.default_currency

      presets.map do |price|
        [number_to_currency(price, unit: currency, precision: 0), price]
      end
    end
  end
end
```

#### Updated Search Form Partial

```erb
<%# app/views/pwb/shared/_property_search_form.html.erb %>
<%# Works for both internal and external listings %>

<%= form_with url: search_path, method: :get, local: true,
              class: "bg-white rounded-lg shadow p-4 lg:sticky lg:top-4",
              data: { controller: "search-form" } do |f| %>

  <h2 class="text-lg font-semibold text-gray-900 mb-4">
    <%= t("search.filters") %>
  </h2>

  <% search_config.enabled_filters.each do |filter_key, config| %>
    <%= render "pwb/shared/filters/#{filter_key}",
               config: config,
               search_params: @search_params,
               search_config: search_config %>
  <% end %>

  <div class="pt-4 border-t">
    <%= f.submit t("search.apply_filters"),
                 class: "w-full bg-blue-600 text-white py-2 px-4 rounded-md..." %>

    <%= link_to t("search.clear_filters"), search_path,
                class: "block w-full text-center mt-2 text-sm text-gray-600..." %>
  </div>
<% end %>
```

#### Price Filter Partial (Hybrid Input)

```erb
<%# app/views/pwb/shared/filters/_price.html.erb %>

<div class="mb-4" data-filter="price">
  <label class="block text-sm font-medium text-gray-700 mb-2">
    <%= t("search.price_range") %>
  </label>

  <div class="grid grid-cols-2 gap-2">
    <%# Min Price %>
    <div>
      <% if config[:input_type] == "dropdown" || config[:input_type] == "dropdown_with_manual" %>
        <select name="min_price" id="min_price"
                class="block w-full rounded-md border-gray-300 shadow-sm text-sm"
                data-action="change->search-form#onPriceChange">
          <option value=""><%= t("search.min") %></option>
          <% search_config.price_presets.each do |price| %>
            <option value="<%= price %>"
                    <%= 'selected' if search_params[:min_price].to_i == price %>>
              <%= number_to_currency(price, unit: current_website.default_currency, precision: 0) %>
            </option>
          <% end %>
          <% if config[:input_type] == "dropdown_with_manual" %>
            <option value="custom"><%= t("search.custom_amount") %></option>
          <% end %>
        </select>

        <% if config[:input_type] == "dropdown_with_manual" %>
          <input type="number" name="min_price_custom" id="min_price_custom"
                 class="mt-2 block w-full rounded-md border-gray-300 shadow-sm text-sm hidden"
                 placeholder="<%= t('search.enter_amount') %>"
                 data-search-form-target="minPriceCustom">
        <% end %>
      <% else %>
        <input type="number" name="min_price" id="min_price"
               value="<%= search_params[:min_price] %>"
               min="<%= config.dig(listing_type, :min) %>"
               max="<%= config.dig(listing_type, :max) %>"
               step="<%= config.dig(listing_type, :step) %>"
               placeholder="<%= t('search.min_price') %>"
               class="block w-full rounded-md border-gray-300 shadow-sm text-sm">
      <% end %>
    </div>

    <%# Max Price - similar structure %>
    <div>
      <!-- ... similar to min price ... -->
    </div>
  </div>
</div>
```

---

### 6. Testing Strategy

#### Unit Tests for SearchConfig

```ruby
# spec/services/pwb/search_config_spec.rb
require "rails_helper"

RSpec.describe Pwb::SearchConfig do
  let(:website) { create(:website) }

  describe "default configuration" do
    subject(:config) { described_class.new(website) }

    it "provides default price presets" do
      expect(config.price_presets).to be_present
      expect(config.price_presets).to all(be_a(Integer))
    end

    it "provides default bedroom options" do
      expect(config.bedroom_options).to eq(["Any", 1, 2, 3, 4, 5, "6+"])
    end

    it "provides default bathroom options" do
      expect(config.bathroom_options).to eq(["Any", 1, 2, 3, 4, "5+"])
    end

    it "returns enabled filters in position order" do
      filters = config.enabled_filters
      positions = filters.map { |_, cfg| cfg[:position] }
      expect(positions).to eq(positions.sort)
    end

    it "defaults to sale listing type" do
      expect(config.listing_type).to eq(:sale)
    end
  end

  describe "custom configuration" do
    before do
      website.update!(search_config: {
        "filters" => {
          "price" => {
            "enabled" => true,
            "input_type" => "dropdown",
            "sale" => {
              "presets" => [100_000, 250_000, 500_000]
            }
          },
          "bedrooms" => {
            "enabled" => false
          }
        },
        "display" => {
          "show_results_map" => true,
          "default_sort" => "price_asc"
        }
      })
    end

    subject(:config) { described_class.new(website) }

    it "uses custom price presets" do
      expect(config.price_presets).to eq([100_000, 250_000, 500_000])
    end

    it "uses custom input type" do
      expect(config.price_input_type).to eq("dropdown")
    end

    it "respects disabled filters" do
      filter_keys = config.enabled_filters.map(&:first)
      expect(filter_keys).not_to include(:bedrooms)
    end

    it "uses custom display settings" do
      expect(config.show_map?).to be true
      expect(config.default_sort).to eq("price_asc")
    end

    it "merges with defaults for unspecified values" do
      # Bathrooms not customized, should have defaults
      expect(config.bathroom_options).to eq(["Any", 1, 2, 3, 4, "5+"])
    end
  end

  describe "#filter_options_for_view" do
    subject(:options) { described_class.new(website).filter_options_for_view }

    it "returns complete options hash for views" do
      expect(options).to include(
        :filters, :price, :price_presets, :price_input_type,
        :bedroom_options, :bathroom_options, :area_presets,
        :listing_types, :sort_options, :display
      )
    end
  end

  describe "listing type specific configuration" do
    before do
      website.update!(search_config: {
        "filters" => {
          "price" => {
            "sale" => { "presets" => [100_000, 500_000] },
            "rental" => { "presets" => [500, 1_000, 2_000] }
          }
        }
      })
    end

    it "returns sale presets for sale listing type" do
      config = described_class.new(website, listing_type: :sale)
      expect(config.price_presets).to eq([100_000, 500_000])
    end

    it "returns rental presets for rental listing type" do
      config = described_class.new(website, listing_type: :rental)
      expect(config.price_presets).to eq([500, 1_000, 2_000])
    end
  end
end
```

#### Request Tests for Admin

```ruby
# spec/requests/site_admin/search_config_spec.rb
require "rails_helper"

RSpec.describe "Site Admin Search Configuration", type: :request do
  let(:website) { create(:website) }
  let(:admin) { create(:user, :site_admin, website: website) }

  before do
    sign_in admin
    allow_any_instance_of(Pwb::ApplicationController)
      .to receive(:current_website).and_return(website)
  end

  describe "GET /site_admin/settings?tab=search" do
    it "displays search configuration form" do
      get site_admin_settings_path(tab: "search")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Search Configuration")
      expect(response.body).to include("Price Range")
      expect(response.body).to include("Bedrooms")
    end

    it "shows current configuration values" do
      website.update!(search_config: {
        "filters" => { "price" => { "sale" => { "presets" => [100_000] } } }
      })

      get site_admin_settings_path(tab: "search")

      expect(response.body).to include("100000")
    end
  end

  describe "PATCH /site_admin/settings" do
    it "updates search configuration" do
      patch site_admin_settings_path, params: {
        tab: "search",
        website: {
          search_config: {
            filters: {
              price: {
                input_type: "dropdown",
                sale: { presets: [200_000, 400_000] }
              },
              bedrooms: { enabled: false }
            },
            display: {
              show_results_map: true,
              default_sort: "price_asc"
            }
          }
        }
      }

      expect(response).to redirect_to(site_admin_settings_path(tab: "search"))

      website.reload
      expect(website.search_config.dig("filters", "price", "input_type")).to eq("dropdown")
      expect(website.search_config.dig("display", "show_results_map")).to be true
    end

    it "preserves existing config when partially updating" do
      website.update!(search_config: {
        "filters" => {
          "price" => { "sale" => { "presets" => [100_000] } },
          "bedrooms" => { "enabled" => true }
        }
      })

      patch site_admin_settings_path, params: {
        tab: "search",
        website: {
          search_config: {
            filters: { price: { input_type: "manual" } }
          }
        }
      }

      website.reload
      # Original presets preserved
      expect(website.search_config.dig("filters", "price", "sale", "presets")).to eq([100_000])
      # New value applied
      expect(website.search_config.dig("filters", "price", "input_type")).to eq("manual")
    end
  end
end
```

#### Integration Tests for Search

```ruby
# spec/requests/property_search_spec.rb
require "rails_helper"

RSpec.describe "Property Search with Configured Filters", type: :request do
  let(:website) { create(:website) }

  before do
    allow_any_instance_of(Pwb::ApplicationController)
      .to receive(:current_website).and_return(website)
  end

  describe "internal listings search" do
    before do
      website.update!(search_config: {
        "filters" => {
          "price" => {
            "sale" => { "presets" => [100_000, 250_000, 500_000] }
          }
        },
        "display" => { "show_results_map" => true }
      })
    end

    it "displays configured price presets" do
      get props_search_path(operation_type: "for-sale")

      expect(response.body).to include("100,000")
      expect(response.body).to include("250,000")
      expect(response.body).to include("500,000")
    end

    it "shows map when configured" do
      get props_search_path(operation_type: "for-sale")

      expect(response.body).to include("search-results-map")
    end
  end

  describe "external listings search" do
    let(:website) { create(:website, :with_external_feed) }

    before do
      website.update!(search_config: {
        "filters" => {
          "price" => {
            "rental" => { "presets" => [500, 1_000, 2_000] }
          }
        }
      })
    end

    it "uses same search config for external listings" do
      get external_listings_path(listing_type: "rental")

      expect(response.body).to include("500")
      expect(response.body).to include("1,000")
      expect(response.body).to include("2,000")
    end
  end
end
```

---

### 7. Implementation Phases

#### Phase 1: Core Infrastructure (3-4 days)
- [ ] Create migration for `search_config` column
- [ ] Implement `Pwb::SearchConfig` service class
- [ ] Add `search_configuration` method to Website model
- [ ] Write comprehensive unit tests
- [ ] Update ExternalFeed::Manager to use SearchConfig

#### Phase 2: Admin Interface (3-4 days)
- [ ] Add "Search" tab to site admin settings
- [ ] Create form partial with all configuration options
- [ ] Implement drag-and-drop filter reordering (Stimulus)
- [ ] Add controller action for updating search config
- [ ] Write admin request tests

#### Phase 3: View Updates (2-3 days)
- [ ] Create unified search form helper
- [ ] Create filter partials for each input type
- [ ] Update internal listings search form
- [ ] Update external listings search form
- [ ] Add map toggle functionality
- [ ] Write integration tests

#### Phase 4: Seed Data (1-2 days)
- [ ] Update SeedPack to handle search_config
- [ ] Add search_config to existing seed packs
- [ ] Create varied example configurations
- [ ] Document seed pack format

#### Phase 5: Documentation & Polish (1-2 days)
- [ ] Admin guide for search configuration
- [ ] Developer documentation
- [ ] Update CLAUDE.md
- [ ] Edge case testing
- [ ] Performance optimization

---

### 8. File Changes Summary

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/xxx_add_search_config_to_websites.rb` | **Create** | Migration |
| `app/services/pwb/search_config.rb` | **Create** | Core service |
| `app/models/pwb/website.rb` | **Update** | Add helper methods |
| `app/controllers/pwb/site_admin/website/settings_controller.rb` | **Update** | Add search tab |
| `app/views/pwb/site_admin/website/settings/_search.html.erb` | **Create** | Admin form |
| `app/views/pwb/site_admin/website/settings/_filter_config.html.erb` | **Create** | Filter config partial |
| `app/helpers/pwb/search_form_helper.rb` | **Create** | View helpers |
| `app/views/pwb/shared/_property_search_form.html.erb` | **Create** | Unified search form |
| `app/views/pwb/shared/filters/_price.html.erb` | **Create** | Price filter partial |
| `app/views/pwb/shared/filters/_bedrooms.html.erb` | **Create** | Bedrooms partial |
| `app/views/pwb/shared/filters/_*.html.erb` | **Create** | Other filter partials |
| `app/services/pwb/external_feed/manager.rb` | **Update** | Use SearchConfig |
| `lib/pwb/seed_pack.rb` | **Update** | Handle search_config |
| `config/locales/en.yml` | **Update** | Add translations |
| `config/locales/es.yml` | **Update** | Add translations |
| `spec/services/pwb/search_config_spec.rb` | **Create** | Unit tests |
| `spec/requests/site_admin/search_config_spec.rb` | **Create** | Admin tests |
| `spec/requests/property_search_spec.rb` | **Create** | Integration tests |
| `docs/admin/search_configuration.md` | **Create** | Admin documentation |

---

## Summary

This revised strategy provides:

1. **Source-agnostic** - Single `search_config` column works for all listing sources
2. **Fully configurable** - Every aspect controllable: visibility, order, input types, defaults, map
3. **Per-website isolation** - Independent configuration per website
4. **Three input modes** - Dropdown only, manual only, or hybrid
5. **Comprehensive admin UI** - Drag-and-drop reordering, per-filter configuration
6. **Seed-friendly** - YAML format for seed packs
7. **Extensive testing** - Unit, request, and integration tests

**Estimated total: 10-15 days of development**

Ready to proceed with Phase 1 upon approval.
