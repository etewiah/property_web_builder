# Research: Property Types & Features for Search Filter Management

**Date:** 2025-01-03  
**Purpose:** Research current implementation of property types and features to plan a comprehensive management system for search filters.

---

## Overview

PropertyWebBuilder has a sophisticated multi-tenant system for managing property types and features. The implementation spans:

1. **Internal Listings** - Using the FieldKey system with normalized RealtyAsset/Listing models
2. **External Feeds** - From providers like Resales Online with custom property type hierarchies
3. **Search Configuration** - Centralized SearchConfig service for filter management
4. **Admin Interface** - Partial admin UI for search settings in site_admin

---

## 1. Field Key System (Internal Listings)

### Database Schema
**Table:** `pwb_field_keys`

```sql
CREATE TABLE "pwb_field_keys" (
  id: serial PRIMARY KEY
  global_key: string (Primary Key - used as lookup)
  tag: string (Categories: property-types, property-states, property-features, property-amenities, property-highlights)
  translations: jsonb (Multi-language labels)
  visible: boolean (Default: true)
  show_in_search_form: boolean (Default: true)
  sort_order: integer (Display ordering)
  props_count: integer (Usage count - properties using this key)
  pwb_website_id: bigint (Tenant scoping - null = shared across websites)
  created_at: datetime
  updated_at: datetime
)

Indexes:
  - (pwb_website_id, global_key) UNIQUE
  - (pwb_website_id, tag)
  - (pwb_website_id)
```

**Key Points:**
- Multi-tenant capable: Can be website-specific (`pwb_website_id`) or global (null)
- Uniqueness scoped by website: Same `global_key` can exist on multiple websites
- Uses Mobility gem for multi-language translations (`label` attribute)
- `props_count` tracks actual usage (helps determine what to show in search dropdowns)

### Model: `Pwb::FieldKey`

**Location:** `/app/models/pwb/field_key.rb`

```ruby
class FieldKey < ApplicationRecord
  extend Mobility
  
  translates :label  # Mobility: provides label, label_en, label_es, etc.
  
  belongs_to :website, optional: true, foreign_key: 'pwb_website_id'
  
  scope :visible, -> { where(visible: true) }
  scope :by_tag, ->(tag) { where(tag: tag) }
  scope :ordered, -> { order(:sort_order, :created_at) }
  
  validates :global_key, uniqueness: { scope: :pwb_website_id }
  validates :tag, presence: true
  
  # Associations for RealtyAsset
  has_many :realty_assets_with_state, class_name: 'Pwb::RealtyAsset', 
                                       foreign_key: 'prop_state_key', 
                                       primary_key: :global_key
  has_many :realty_assets_with_type, class_name: 'Pwb::RealtyAsset', 
                                      foreign_key: 'prop_type_key', 
                                      primary_key: :global_key
  has_many :features, class_name: 'Pwb::Feature', 
                      foreign_key: 'feature_key', 
                      primary_key: :global_key
end
```

**Key Methods:**
- `get_options_by_tag(tag)` - Returns array of OpenStruct options for dropdowns
  - Filters by tag (e.g., 'property-types')
  - Returns visible, ordered records
  - Each with `:value` (global_key), `:label` (translated), `:sort_order`

### Tags (Categories)

```
property-types       → apartment, villa, townhouse, etc.
property-states      → good, needs-renovation, etc.
property-features    → pool, garden, garage, etc.
property-amenities   → gym, parking, security, etc.
property-highlights  → new, reduced, exclusive, etc.
```

---

## 2. Features System

### Database Schema
**Table:** `pwb_features`

```sql
CREATE TABLE "pwb_features" (
  id: serial PRIMARY KEY
  feature_key: string (Reference to FieldKey.global_key)
  realty_asset_id: uuid (FK to pwb_realty_assets)
  prop_id: integer (Legacy - for backwards compatibility)
  created_at: datetime
  updated_at: datetime
)

Indexes:
  - (feature_key)
  - (realty_asset_id, feature_key) UNIQUE
  - (realty_asset_id)
```

### Model: `Pwb::Feature`

**Location:** `/app/models/pwb/feature.rb`

```ruby
class Feature < ActiveRecord::Base
  belongs_to :realty_asset, optional: true
  belongs_to :prop, optional: true  # Legacy support
  
  belongs_to :feature_field_key, optional: true, 
             class_name: 'Pwb::FieldKey',
             foreign_key: :feature_key, 
             primary_key: :global_key
end
```

**How Features Are Used:**
1. Properties have many features (via realty_asset_id)
2. Each feature references a FieldKey via feature_key
3. Features are searchable via SearchConfig
4. Stored as simple boolean presence (property has feature or doesn't)

### RealtyAsset Integration

```ruby
class RealtyAsset < ApplicationRecord
  has_many :features, class_name: 'PwbTenant::Feature'
  
  # Get features as hash: { feature_key => true, ... }
  def get_features
    Hash[features.map { |f| [f.feature_key, true] }]
  end
  
  # Set features from JSON hash
  def set_features=(features_json)
    return unless features_json.is_a?(Hash)
    features_json.each do |feature_key, value|
      if value
        features.find_or_create_by(feature_key: feature_key)
      else
        features.where(feature_key: feature_key).delete_all
      end
    end
  end
end
```

---

## 3. SearchConfig Service

### Purpose
Unified interface for accessing search options. Configurable per website with sensible defaults. Works for both internal listings and external feeds.

**Location:** `/app/services/pwb/search_config.rb`

### Configuration Structure

```ruby
config = {
  filters: {
    reference: {
      enabled: true,
      position: 0,
      input_type: "text"
    },
    price: {
      enabled: true,
      position: 1,
      input_type: "dropdown_with_manual",
      sale: { min: 0, max: 10M, step: 50k, min_presets: [...], max_presets: [...] },
      rental: { min: 0, max: 20k, step: 100, min_presets: [...], max_presets: [...] }
    },
    bedrooms: {
      enabled: true,
      position: 2,
      input_type: "dropdown",
      min_options: ["Any", 1, 2, 3, 4, 5, "6+"],
      max_options: [1, 2, 3, 4, 5, 6, "No max"],
      show_max_filter: false
    },
    bathrooms: {
      enabled: true,
      position: 3,
      input_type: "dropdown",
      min_options: ["Any", 1, 2, 3, 4, "5+"],
      max_options: [1, 2, 3, 4, 5, "No max"],
      show_max_filter: false
    },
    area: {
      enabled: true,
      position: 4,
      input_type: "dropdown_with_manual",
      unit: "sqm",
      presets: [25, 50, 75, 100, 150, 200, 300, 400, 500, 750, 1000, ...]
    },
    property_type: {
      enabled: true,
      position: 5,
      input_type: "checkbox",
      allow_multiple: true
    },
    location: {
      enabled: true,
      position: 6,
      input_type: "dropdown",
      allow_multiple: false
    },
    features: {
      enabled: false,
      position: 7,
      input_type: "checkbox",
      allow_multiple: true
    }
  },
  display: {
    show_results_map: false,
    show_active_filters: true,
    show_save_search: true,
    show_favorites: true,
    default_sort: "newest",
    sort_options: ["price_asc", "price_desc", "newest", "updated"],
    card_layout: "grid"
  },
  listing_types: {
    sale: { enabled: true, is_default: true },
    rental: { enabled: true, is_default: false }
  }
}
```

### Storage
- Stored in `Pwb::Website.search_config` (JSON column)
- Deep-merged with `SearchConfig::DEFAULT_CONFIG` at runtime
- Can be customized per website while maintaining sensible fallbacks

### Key Methods

```ruby
config = Pwb::SearchConfig.new(website, listing_type: :sale)

# Filter access
config.enabled_filters           # [[:price, {...}], [:bedrooms, {...}], ...]
config.filter(:price)            # Get specific filter config
config.filter_enabled?(:price)   # Check if enabled

# Price
config.price_min_presets         # [50k, 100k, 200k, ...]
config.price_max_presets
config.price_input_type
config.default_min_price

# Bedroom/Bathroom
config.bedroom_min_options       # ["Any", 1, 2, 3, 4, 5, "6+"]
config.bedroom_max_options
config.show_max_bedrooms?

# Area
config.area_presets
config.area_unit                 # "sqm" or "sqft"

# Listing types
config.enabled_listing_types     # [:sale, :rental]
config.default_listing_type

# Display
config.show_map?
config.default_sort              # "newest"
config.results_per_page_options  # [12, 24, 48]

# View helpers
config.filter_options_for_view   # Hash ready for view rendering
config.bedroom_options_for_view  # [{ value: "", label: "Any" }, ...]
config.sort_options_for_view
```

---

## 4. External Feeds & Property Types

### External Feed Manager

**Location:** `/app/services/pwb/external_feed/manager.rb`

- Main entry point for external feed operations
- Provides unified interface across different providers
- Caches results to reduce API calls
- Methods: `search()`, `find()`, `locations()`, `property_types()`, `features()`

### Normalized Property Structure

**Location:** `/app/services/pwb/external_feed/normalized_property.rb`

```ruby
class NormalizedProperty
  # Core IDs
  reference              # Provider's unique ID
  provider               # Symbol (:resales_online, etc.)
  provider_url           # Original listing URL
  
  # Property Info
  title, description
  property_type          # Normalized: apartment, villa, townhouse, etc.
  property_type_raw      # Provider's original code (e.g., "1-1" for Resales)
  property_subtype       # More specific: penthouse, ground-floor, etc.
  
  # Location
  country, region, area, city, address, postal_code
  latitude, longitude
  
  # Listing Details
  listing_type           # :sale or :rental
  status                 # :available, :reserved, :sold, :rented, :unavailable
  price, price_raw, currency
  original_price, price_qualifier
  
  # Rental-specific
  rental_period          # :monthly, :weekly, :daily
  available_from, minimum_stay
  
  # Property Details
  bedrooms, bathrooms, built_area, plot_area, terrace_area
  year_built, floors, floor_level, orientation
  
  # Features
  features               # Array<String> - flat list
  features_by_category   # Hash<String, Array<String>> - organized by category
  
  # Energy
  energy_rating, energy_value
  co2_rating, co2_value
  
  # Media
  images, virtual_tour_url, video_url, floor_plan_urls
  
  # Costs
  community_fees, ibi_tax, garbage_tax
  
  # Metadata
  created_at, updated_at, fetched_at
end
```

### Resales Online Provider Example

**Location:** `/app/services/pwb/external_feed/providers/resales_online.rb`

**Configuration:**
```ruby
external_feed_config: {
  api_key: "...",
  api_id_sales: "...",
  api_id_rentals: "..." (optional, falls back to api_id_sales),
  p1_constant: "..." (optional, uses default if not set),
  locations: [...],    # Custom location options
  property_types: [...], # Custom property type options
  features: {...}      # Feature key mappings
}
```

**Default Property Types:**
```ruby
[
  {
    value: "1-1",
    label: "Apartment",
    subtypes: [
      { value: "1-2", label: "Ground Floor Apartment" },
      { value: "1-4", label: "Middle Floor Apartment" },
      { value: "1-5", label: "Top Floor Apartment" },
      { value: "1-6", label: "Penthouse" },
      { value: "1-7", label: "Duplex" }
    ]
  },
  {
    value: "2-1",
    label: "House",
    subtypes: [...]
  },
  { value: "3-1", label: "Plot / Land" },
  { value: "4-1", label: "Commercial" }
]
```

**Default Locations:**
Marbella, Estepona, Benahavís, Mijas, Fuengirola, etc. (20+ Costa del Sol locations)

**Default Features:**
Extracted from property API response with categories (e.g., Bathrooms, Garden, Pool)

**Type Normalization:**
Maps provider-specific names to normalized values:
- "penthouse" → "penthouse"
- "apartment", "flat", "duplex" → "apartment"
- "villa", "detached" → "villa"
- "townhouse", "terraced" → "townhouse"
- etc.

---

## 5. Admin Interface for Search Settings

### Current Admin UI

**Location:** `/app/controllers/site_admin/website/settings_controller.rb`

**Search Tab:** `/site_admin/website/settings?tab=search`

**Current Functionality:**
- Enable/disable individual filters
- Set filter positions (ordering)
- Configure price presets (min/max for sales/rentals)
- Configure bedroom/bathroom options (min/max separate)
- Configure area presets
- Set display options (map, active filters, save search, favorites)
- Set default sort option
- Reset to defaults

**Limitations:**
1. **No Field Key Management**
   - Can't add/edit/delete property types via admin
   - Can't manage feature lists
   - Can't reorder property types in search
   - Can't set translations for property types

2. **No Feature Management**
   - Features are only added via property editing
   - No centralized feature inventory
   - No way to control which features appear in search

3. **No External Feed Configuration UI**
   - Location configuration only in code (provider defaults)
   - Property type mapping hardcoded
   - Feature mappings require code changes

4. **Limited Search Form Customization**
   - Can't conditionally show/hide based on listing type
   - Limited input type options
   - No field dependencies

---

## 6. Data Flow: From Seed to Search

### Seeding Process

**Locations:** 
- `/lib/pwb/seeder.rb` - Main seeder for legacy properties
- `/lib/pwb/seed_pack.rb` - Scenario-based seed packs with YML structure

**Field Keys Seeding:**
```yaml
# db/yml_seeds/field_keys.yml
- global_key: types.apartment
  tag: property-types
  show_in_search_form: true
  sort_order: 1
  translations:
    en: Apartment
    es: Apartamento
    de: Wohnung
- global_key: types.villa
  tag: property-types
  show_in_search_form: true
  sort_order: 2
  translations:
    en: Villa
    es: Villa
```

**Property Seeding:**
```yaml
# db/yml_seeds/prop/villa_for_sale.yml
- reference: "VILLA-001"
  prop_type_key: types.villa
  prop_state_key: states.good
  bedrooms: 3
  bathrooms: 2.5
  price_sale_current_cents: 75000000  # €750,000
  for_sale: true
  visible: true
  features:
    - features.pool
    - features.garden
    - features.garage
```

### Search Form Rendering

**Internal Listings:**
1. Get SearchConfig for website
2. Get enabled filters with positions
3. For property_type filter: Call `PwbTenant::FieldKey.get_options_by_tag('property-types')`
4. For features filter: Call `PwbTenant::FieldKey.get_options_by_tag('property-features')`
5. Render form with fetched options

**External Feeds:**
1. Get SearchConfig for website
2. Get external feed manager
3. Call `feed.property_types()` - returns provider defaults or custom config
4. Call `feed.features()` - returns provider defaults or extracted from API
5. Call `feed.locations()` - returns provider defaults or custom config
6. Render form with fetched options

---

## 7. Tenant Scoping

### Multi-Tenancy Pattern

```ruby
# Shared global field keys (pwb_website_id = nil)
Pwb::FieldKey.where(pwb_website_id: nil)
  # Available to all websites

# Website-specific field keys
Pwb::FieldKey.where(pwb_website_id: website.id)
  # Only visible to this website

# Querying in tenant context (within web request)
# Uses acts_as_tenant gem
ActsAsTenant.with_tenant(website) do
  PwbTenant::FieldKey.by_tag('property-types')
  # Automatically scoped to current website
end
```

### Tenant-Scoped Models

- `PwbTenant::FieldKey` - Scoped to website
- `PwbTenant::Feature` - Scoped to website
- `PwbTenant::RealtyAsset` - Scoped to website
- `PwbTenant::SavedSearch` - Scoped to website

### Non-Tenant-Scoped (Global)

- `Pwb::FieldKey` - Can be website-specific OR global
- `Pwb::Feature` - Can be website-specific OR global
- `I18n::Backend::ActiveRecord::Translation` - Global translations

---

## 8. Key Implementation Gaps

### 1. Admin UI for Field Key Management
**Missing:** 
- Add/edit/delete property types via admin interface
- Reorder property types within a website
- Bulk import property types
- Set multi-language translations via admin

**Impact:**
- Websites must use seed files or console for property type changes
- Can't customize property type inventory per website via UI
- Difficult to maintain multiple websites with different type needs

### 2. Feature Management Interface
**Missing:**
- Centralized feature inventory admin
- Feature grouping/categorization
- Feature search form inclusion toggle
- Feature translations per website

**Impact:**
- Features only manageable via property editing
- No control over which features appear in search filters
- Difficult to ensure consistent feature usage across properties

### 3. External Feed Type Mapping
**Missing:**
- UI to map provider property types to internal normalized types
- Customizable location options per website
- Feature code mapping configuration
- Fallback property type for unmapped values

**Impact:**
- Property type mappings are hardcoded in provider classes
- Each provider needs custom configuration code
- Difficult to update location lists without code changes

### 4. Dynamic Filter Configuration
**Missing:**
- Conditional filter visibility based on listing type or property type
- Custom filter input types (range sliders, multi-select chips, etc.)
- Filter inter-dependencies (e.g., "show features if property_type = villa")
- Filter help text/descriptions for users

**Impact:**
- Same filters shown for all listing types
- Limited UI customization options
- Can't create advanced search experiences

### 5. Search Form Testing
**Missing:**
- Admin preview of search form with current configuration
- Live testing of search results with different filter combinations
- Property type coverage analysis (unused types)
- Feature usage analytics

**Impact:**
- Can't verify search form changes before deploying
- No visibility into feature adoption
- Difficult to optimize filter options

---

## 9. Recommended Management System Architecture

### Core Components

#### 1. Property Type Manager
- CRUD interface for property types per website
- Reordering/positioning UI
- Multi-language translation editor
- Batch import/export
- Visibility toggles (search form, property editing)
- Sub-type hierarchy support

#### 2. Feature Manager
- Centralized feature inventory
- Feature categorization/grouping
- Translation management
- Search form inclusion settings
- Usage analytics (how many properties have this feature)

#### 3. External Feed Configurator
- UI for property type mapping
- Location options manager
- Feature code mapping
- Fallback type configuration
- Test connection + sample data preview

#### 4. Search Form Designer
- Visual form builder with drag-to-reorder
- Filter enable/disable toggles
- Input type selector with preview
- Conditional visibility rules
- Field dependencies configuration
- Help text/descriptions editor

#### 5. Search Analytics Dashboard
- Filter usage statistics
- Property type distribution
- Feature adoption rates
- Performance metrics (search speed, result counts)
- Common search patterns

### Data Model Enhancements

#### Enhance FieldKey
```ruby
add_column :pwb_field_keys, :icon, :string          # For UI display
add_column :pwb_field_keys, :description, :text     # Help text
add_column :pwb_field_keys, :parent_key, :string    # Sub-type hierarchy
add_column :pwb_field_keys, :external_mappings, :jsonb # Provider type mappings
```

#### New: Feature Category
```ruby
create_table :pwb_feature_categories do |t|
  t.string :global_key, null: false
  t.jsonb :translations                # name translations
  t.integer :sort_order, default: 0
  t.bigint :pwb_website_id
  t.timestamps
end
```

#### New: External Type Mapping
```ruby
create_table :pwb_external_type_mappings do |t|
  t.string :provider, null: false           # :resales_online
  t.string :external_type, null: false      # Provider code: "1-1"
  t.string :normalized_type                 # apartment, villa, etc.
  t.string :internal_field_key             # types.apartment
  t.bigint :pwb_website_id                 # Website-specific mapping
  t.timestamps
  
  t.index [:provider, :external_type, :pwb_website_id], unique: true
end
```

---

## 10. File Locations Summary

### Core Models
- `app/models/pwb/field_key.rb` - FieldKey model
- `app/models/pwb/feature.rb` - Feature model
- `app/models/pwb/realty_asset.rb` - Main property model (includes features)
- `app/models/pwb_tenant/field_key.rb` - Tenant-scoped FieldKey
- `app/models/pwb_tenant/feature.rb` - Tenant-scoped Feature

### Services
- `app/services/pwb/search_config.rb` - Search configuration service
- `app/services/pwb/external_feed/manager.rb` - External feed manager
- `app/services/pwb/external_feed/base_provider.rb` - Provider base class
- `app/services/pwb/external_feed/providers/resales_online.rb` - Example provider

### Controllers
- `app/controllers/site_admin/website/settings_controller.rb` - Settings (includes search tab)
- `app/controllers/site_admin/external_feeds_controller.rb` - External feed configuration
- `app/controllers/pwb/search_controller.rb` - Search functionality

### Views
- `app/views/pwb/search/_search_form_for_sale.html.erb`
- `app/views/pwb/search/_search_form_for_rent.html.erb`
- `app/views/site_admin/website/settings/search.html.erb` (implied - part of show)

### Seeders
- `lib/pwb/seeder.rb` - Main seeder
- `lib/pwb/seed_pack.rb` - Seed pack system
- `db/yml_seeds/field_keys.yml` - Default field keys
- `db/seeds/packs/*/field_keys.yml` - Pack-specific field keys

### Migrations
- `db/migrate/20161123232423_create_pwb_field_keys.rb`
- `db/migrate/20161130141845_create_pwb_features.rb`
- `db/migrate/20251204135225_add_website_id_to_field_keys.rb`
- `db/migrate/20251204140232_add_sort_order_to_field_keys.rb`
- `db/migrate/20251217095831_add_translations_to_pwb_field_keys.rb`

### Database Schema
- `db/schema.rb` - Full schema definition

---

## 11. Current Admin UI Implementation

**File:** `app/controllers/site_admin/website/settings_controller.rb`

**Key Methods:**
- `update_search_settings()` - Parses and saves search config
- `build_search_config_from_params()` - Converts form params to nested hash
- `build_filter_config()` - Builds individual filter configuration
- `parse_price_presets()` - Handles "No min" / "No max" special values
- `parse_options()` - Converts "Any", "6+", numbers for dropdowns

**Example Form Structure:**
```
search_config[filters][price][enabled]
search_config[filters][price][position]
search_config[filters][price][input_type]
search_config[filters][price][sale][min]
search_config[filters][price][sale][max]
search_config[filters][price][sale][step]
search_config[filters][price][sale][min_presets]
search_config[filters][price][sale][max_presets]
...
search_config[display][show_results_map]
search_config[display][default_sort]
```

---

## Conclusion

PropertyWebBuilder has a well-designed foundation for managing property types and features:

- **FieldKey system** provides multi-tenant, multi-language property type definitions
- **SearchConfig service** centralizes filter configuration with sensible defaults
- **External feed support** allows integration with third-party providers
- **Seeding system** enables scenario-based tenant setup with YML configuration

However, **the management interface is incomplete**:

- Field keys and features can only be managed via code/console
- External feed types require custom provider code
- No admin UI for centralizing and maintaining this critical data
- No analytics or testing tools for search forms

A comprehensive management system would need to add:

1. Admin CRUD interfaces for field keys, features, and categories
2. External type mapping configuration UI
3. Visual search form designer with live preview
4. Analytics dashboard for filter usage and coverage
5. Data model enhancements to support hierarchies and external mappings
6. Validation and conflict detection (unused types, unmapped codes, etc.)

---

**End of Research Document**
