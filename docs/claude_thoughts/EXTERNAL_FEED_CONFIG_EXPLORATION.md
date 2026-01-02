# External Feed Configuration System - Detailed Analysis

**Date:** January 2, 2026  
**Status:** Complete exploration and documentation

## Overview

This document provides a comprehensive analysis of how the PropertyWebBuilder external feed configuration system works, including storage, structure, filter options, and admin interfaces.

---

## 1. Website Model Configuration Storage

### Location
- **File:** `/app/models/pwb/website.rb`
- **Table:** `pwb_websites`

### Database Schema

The Website model stores external feed configuration in three columns:

```ruby
# Migration: db/migrate/20260101211558_add_external_feed_to_websites.rb
add_column :pwb_websites, :external_feed_enabled, :boolean, default: false, null: false
add_column :pwb_websites, :external_feed_provider, :string
add_column :pwb_websites, :external_feed_config, :json, default: {}

add_index :pwb_websites, :external_feed_enabled
add_index :pwb_websites, :external_feed_provider
```

### Model Methods

The Website model includes utility methods for external feed management:

```ruby
def external_feed_enabled?
  external_feed_enabled && external_feed_provider.present?
end

def external_feed
  @external_feed ||= Pwb::ExternalFeed::Manager.new(self)
end

def configure_external_feed(provider:, config:, enabled: true)
  update!(
    external_feed_enabled: enabled,
    external_feed_provider: provider.to_s,
    external_feed_config: config
  )
end

def disable_external_feed
  update!(external_feed_enabled: false)
end

def clear_external_feed_cache
  external_feed.invalidate_cache if external_feed_enabled?
end
```

### Configuration Schema

The `external_feed_config` JSON column stores provider-specific settings:

```ruby
{
  # Common fields (all providers)
  "provider" => "resales_online",
  "cache_ttl_search" => 3600,        # 1 hour
  "cache_ttl_property" => 86400,     # 24 hours
  "default_locale" => "en",
  "supported_locales" => ["en", "es", "fr", "de", "nl"],
  "results_per_page" => 24,

  # Provider-specific fields (Resales Online example)
  "api_key" => "your_api_key",
  "api_id_sales" => "1234",
  "api_id_rentals" => "5678",
  "p1_constant" => "1014359",
  "default_country" => "Spain",
  "image_count" => 0,  # 0 = all images

  # Optional custom field mappings
  "property_type_labels" => { ... },
  "feature_mappings" => { ... },
  "locations" => [ ... ]
}
```

---

## 2. ExternalFeed::Manager - Filter Options Structure

### Location
- **File:** `/app/services/pwb/external_feed/manager.rb`

### Filter Options Method

The Manager provides the `filter_options` method that returns all available filter configurations for search forms:

```ruby
# Line 138-155
def filter_options(params = {})
  {
    locations: locations(params),
    property_types: property_types(params),
    listing_types: [
      { value: "sale", label: I18n.t("external_feed.listing_types.sale", default: "For Sale") },
      { value: "rental", label: I18n.t("external_feed.listing_types.rental", default: "For Rent") }
    ],
    sort_options: [
      { value: "price_asc", label: I18n.t("external_feed.sort.price_asc", default: "Price (Low to High)") },
      { value: "price_desc", label: I18n.t("external_feed.sort.price_desc", default: "Price (High to Low)") },
      { value: "newest", label: I18n.t("external_feed.sort.newest", default: "Newest First") },
      { value: "updated", label: I18n.t("external_feed.sort.updated", default: "Recently Updated") }
    ],
    bedrooms: (1..6).map { |n| { value: n.to_s, label: "#{n}+" } },
    bathrooms: (1..4).map { |n| { value: n.to_s, label: "#{n}+" } }
  }
end
```

### Filter Options Structure

The method returns a hash with these keys:

| Key | Type | Source | Description |
|-----|------|--------|-------------|
| `locations` | Array<Hash> | Provider | Dynamic locations from provider (e.g., Costa del Sol cities) |
| `property_types` | Array<Hash> | Provider | Dynamic property types from provider |
| `listing_types` | Array<Hash> | Static | Hardcoded: sale, rental |
| `sort_options` | Array<Hash> | Static | Hardcoded: price_asc, price_desc, newest, updated |
| `bedrooms` | Array<Hash> | Static | Hardcoded: 1+, 2+, 3+, 4+, 5+, 6+ |
| `bathrooms` | Array<Hash> | Static | Hardcoded: 1+, 2+, 3+, 4+ |

### Example Filter Response

```json
{
  "locations": [
    { "value": "Marbella", "label": "Marbella" },
    { "value": "Estepona", "label": "Estepona" },
    { "value": "Benahavis", "label": "Benahavís" }
  ],
  "property_types": [
    {
      "value": "1-1",
      "label": "Apartment",
      "subtypes": [
        { "value": "1-2", "label": "Ground Floor Apartment" },
        { "value": "1-4", "label": "Middle Floor Apartment" },
        { "value": "1-5", "label": "Top Floor Apartment" }
      ]
    },
    {
      "value": "2-1",
      "label": "House",
      "subtypes": [...]
    }
  ],
  "listing_types": [
    { "value": "sale", "label": "For Sale" },
    { "value": "rental", "label": "For Rent" }
  ],
  "sort_options": [
    { "value": "price_asc", "label": "Price (Low to High)" },
    { "value": "price_desc", "label": "Price (High to Low)" },
    { "value": "newest", "label": "Newest First" },
    { "value": "updated", "label": "Recently Updated" }
  ],
  "bedrooms": [
    { "value": "1", "label": "1+" },
    { "value": "2", "label": "2+" },
    { "value": "3", "label": "3+" },
    { "value": "4", "label": "4+" },
    { "value": "5", "label": "5+" },
    { "value": "6", "label": "6+" }
  ],
  "bathrooms": [
    { "value": "1", "label": "1+" },
    { "value": "2", "label": "2+" },
    { "value": "3", "label": "3+" },
    { "value": "4", "label": "4+" }
  ]
}
```

### Manager Initialization

```ruby
def initialize(website)
  @website = website
  @config = (website.external_feed_config || {}).deep_symbolize_keys
  @cache = CacheStore.new(website)
end
```

The Manager:
- Loads config from `website.external_feed_config` (JSON)
- Deep symbolizes keys for Ruby access
- Provides caching layer
- Delegates to provider for dynamic data

---

## 3. External Listings Controller

### Location
- **File:** `/app/controllers/pwb/site/external_listings_controller.rb`

### Controller Actions

#### Index/Search
```ruby
def index
  @search_params = search_params
  @result = external_feed.search(@search_params)
  @filter_options = external_feed.filter_options(locale: I18n.locale)
  # responds to both .html and .json
end
```

**Permitted Search Parameters:**
- `:listing_type` - sale or rental
- `:location` - city/area name
- `:min_price`, `:max_price` - price range
- `:min_bedrooms`, `:max_bedrooms` - bedroom range
- `:min_bathrooms` - minimum bathrooms
- `:max_bathrooms` - maximum bathrooms
- `:min_area`, `:max_area` - built area in sqm
- `:sort` - sort order (price_asc, price_desc, newest, updated)
- `:page` - pagination (default: 1)
- `:per_page` - results per page
- `:property_types[]` - array of property type codes
- `:features[]` - array of feature names

#### Show (Property Details)
```ruby
def show
  # Sets @listing via before_action
  # Checks if available, otherwise renders unavailable status
  # Loads @similar properties (6 similar)
end
```

#### Similar
```ruby
def similar
  # GET /external_listings/:reference/similar
  # Returns similar properties for a given listing
  # Limit parameter: 1-20 (default: 8)
  # Responds to both .html (partial) and .json
end
```

#### API Endpoints
```ruby
def locations
  # GET /external_listings/locations
  # Returns available locations for filters
  render json: @locations
end

def property_types
  # GET /external_listings/property_types
  # Returns available property types for filters
  render json: @property_types
end

def filters
  # GET /external_listings/filters
  # Returns all filter options
  render json: @filter_options
end
```

### Search Params Processing

```ruby
def search_params
  permitted = params.permit(
    :listing_type, :location, :min_price, :max_price,
    :min_bedrooms, :max_bedrooms, :min_bathrooms, :max_bathrooms,
    :min_area, :max_area, :sort, :page, :per_page,
    property_types: [], features: []
  ).to_h.symbolize_keys

  # Set defaults
  permitted[:locale] = I18n.locale
  permitted[:listing_type] = permitted[:listing_type].present? ? 
    permitted[:listing_type].to_sym : :sale
  permitted[:page] ||= 1

  permitted
end
```

---

## 4. Site Admin External Feeds Controller

### Location
- **File:** `/app/controllers/site_admin/external_feeds_controller.rb`

### Admin Actions

#### Show (Configuration Page)
```ruby
def show
  @providers = available_providers
  @feed_status = feed_status_info
end
```

Displays:
- List of available providers with configuration fields
- Current feed status and configuration

#### Update (Save Configuration)
```ruby
def update
  if @website.update(external_feed_params)
    # Clear cache when configuration changes
    @website.external_feed.invalidate_cache if @website.external_feed_enabled?
    redirect_to site_admin_external_feed_path, notice: "External feed settings updated successfully"
  else
    # Show form again with errors
  end
end
```

#### Test Connection
```ruby
def test_connection
  feed = @website.external_feed
  result = feed.search(page: 1, per_page: 1)
  
  if result.error?
    redirect_to site_admin_external_feed_path, alert: "Connection failed: #{result.error}"
  else
    redirect_to site_admin_external_feed_path, 
                notice: "Connection successful! Found #{result.total_count} properties."
  end
end
```

#### Clear Cache
```ruby
def clear_cache
  @website.external_feed.invalidate_cache
  redirect_to site_admin_external_feed_path, notice: "Cache cleared successfully"
end
```

### Provider Configuration Fields

The controller dynamically builds configuration forms based on provider type:

#### Resales Online Config Fields
```ruby
[
  {
    key: :api_key,
    label: "API Key",
    type: :password,
    required: true,
    help: "Your Resales Online API key"
  },
  {
    key: :api_id_sales,
    label: "API ID (Sales)",
    type: :text,
    required: true,
    help: "API ID for sales listings"
  },
  {
    key: :api_id_rentals,
    label: "API ID (Rentals)",
    type: :text,
    required: false,
    help: "API ID for rental listings (optional, uses Sales ID if not set)"
  },
  {
    key: :p1_constant,
    label: "P1 Constant",
    type: :text,
    required: false,
    help: "P1 constant for API calls (optional, uses default if not set)"
  }
]
```

### Parameter Handling

```ruby
def external_feed_params
  # Handle both pwb_website and website keys
  param_key = params.key?(:pwb_website) ? :pwb_website : :website

  permitted = params.require(param_key).permit(
    :external_feed_enabled,
    :external_feed_provider
  )

  # Handle nested config hash - filter out empty values and masked passwords
  if params[param_key][:external_feed_config].present?
    config_params = params[param_key][:external_feed_config].to_unsafe_h
    config_params = config_params.reject { |_k, v| v.blank? || v == "••••••••••••" }

    # Merge with existing to preserve unchanged secrets
    if @website.external_feed_config.present?
      existing_config = @website.external_feed_config.dup
      config_params.each do |key, value|
        existing_config[key] = value unless value == "••••••••••••"
      end
      permitted[:external_feed_config] = existing_config
    else
      permitted[:external_feed_config] = config_params
    end
  end

  permitted
end
```

---

## 5. Provider System

### Location
- **Base:** `/app/services/pwb/external_feed/base_provider.rb`
- **Registry:** `/app/services/pwb/external_feed/registry.rb`
- **Initializer:** `/config/initializers/external_feeds.rb`

### Provider Registration

Providers are registered at boot time:

```ruby
# config/initializers/external_feeds.rb
Rails.application.config.to_prepare do
  Pwb::ExternalFeed::Registry.register(Pwb::ExternalFeed::Providers::ResalesOnline)

  if Rails.env.development?
    providers = Pwb::ExternalFeed::Registry.available_providers
    Rails.logger.info "[ExternalFeeds] Registered providers: #{providers.join(', ')}"
  end
end
```

### Current Providers

#### Resales Online
- **File:** `/app/services/pwb/external_feed/providers/resales_online.rb`
- **Status:** Fully implemented
- **Region:** Spain (Costa del Sol)
- **Features:**
  - Search properties (sales & rentals)
  - Find individual properties
  - Similar properties
  - Multiple languages (EN, ES, DE, FR, NL, DA, RU, SV, PL, NO, TR)
  - Energy ratings
  - Feature extraction

### Provider Interface

All providers inherit from `BaseProvider` and must implement:

```ruby
class MyProvider < BaseProvider
  def self.provider_name
    :my_provider
  end

  def search(params)          # -> NormalizedSearchResult
  def find(reference, params) # -> NormalizedProperty or nil
  def similar(property, params) # -> Array<NormalizedProperty>
  def locations(params)       # -> Array<Hash> {value, label}
  def property_types(params)  # -> Array<Hash> {value, label, subtypes?}
  def available?              # -> Boolean
  
  protected
  def required_config_keys    # -> Array<Symbol>
end
```

### Provider Configuration

Each provider defines required keys:

```ruby
# Resales Online
protected
def required_config_keys
  [:api_key, :api_id_sales]
end
```

---

## 6. Data Normalization

### NormalizedProperty

**File:** `/app/services/pwb/external_feed/normalized_property.rb`

Standard property structure with 80+ attributes:

**Identification:**
- `reference` - Provider's unique ID
- `provider` - Provider name (symbol)
- `provider_url` - Original listing URL

**Basic Info:**
- `title`, `description`
- `property_type` - Normalized (apartment, villa, house, etc.)
- `property_type_raw` - Provider's type
- `property_subtype` - More specific type

**Location:**
- `country`, `region`, `area`, `city`
- `address`, `postal_code`
- `latitude`, `longitude`

**Listing Details:**
- `listing_type` - :sale or :rental
- `status` - :available, :reserved, :sold, :rented, :unavailable
- `price` - Integer (in cents)
- `price_raw` - Original string
- `currency` - ISO code
- `original_price` - Previous price if reduced

**Property Details:**
- `bedrooms`, `bathrooms`
- `built_area`, `plot_area`, `terrace_area` (sqm)
- `year_built`, `floors`, `floor_level`
- `orientation`

**Features:**
- `features` - Array<String>
- `features_by_category` - Hash<Category, Array<Features>>

**Energy:**
- `energy_rating` - A-G
- `energy_value` - Float
- `co2_rating`, `co2_value`

**Media:**
- `images` - Array of {url, caption, position}
- `virtual_tour_url`, `video_url`
- `floor_plan_urls`

**Costs:**
- `community_fees` - Annual (cents)
- `ibi_tax` - Annual (cents)
- `garbage_tax` - Annual (cents)

**Helper Methods:**
```ruby
property.price_in_units          # Price in major units (not cents)
property.price_in_units(:built)  # Price per sqm (built area)
property.formatted_price         # "EUR 450,000"
property.primary_image_url       # First image
property.available?              # status == :available
property.price_reduced?          # original_price > price
property.price_reduction_percent # Percentage reduced
property.full_location           # "City, Area, Region, Country"
property.has_feature?(name)      # Check for feature
```

### NormalizedSearchResult

**File:** `/app/services/pwb/external_feed/normalized_search_result.rb`

Wraps search results with pagination:

```ruby
result = search(params)

result.properties       # Array<NormalizedProperty>
result.total_count      # Integer
result.page             # Current page (1-indexed)
result.per_page         # Results per page
result.total_pages      # Calculated
result.query_params     # The search params used
result.provider         # Provider symbol
result.fetched_at       # When fetched
result.error            # Error message if failed

# Helper methods
result.empty?           # No properties found
result.any?             # Has properties
result.first_page?      # page == 1
result.last_page?       # page >= total_pages
result.next_page        # Next page number or nil
result.prev_page        # Previous page number or nil
result.results_range    # "1-24 of 150"
```

---

## 7. Caching Strategy

### Cache Store

**File:** `/app/services/pwb/external_feed/cache_store.rb`

Cache keys follow pattern:
```
pwb:external_feed:{website_id}:{provider}:{operation}:{params_hash}
```

Default TTLs:
| Operation | TTL | Configurable |
|-----------|-----|--------------|
| Search | 1 hour (3600s) | `cache_ttl_search` |
| Property details | 24 hours (86400s) | `cache_ttl_property` |
| Similar properties | 6 hours (21600s) | `cache_ttl_similar` |
| Static data (locations, types) | 1 week (604800s) | `cache_ttl_static` |

### Invalidation

```ruby
manager.invalidate_cache  # Clear all for website
```

---

## 8. Admin Interface Documentation

### Location
- **File:** `/docs/admin/external_feeds.md`

The admin documentation includes:
- How to access configuration
- Provider-specific settings for Resales Online
- Test connection functionality
- Cache clearing
- Troubleshooting guide
- Security notes about API key masking

### Configuration Page URL
```
/site_admin/external_feed
```

---

## 9. Architecture Documentation

### Location
- **File:** `/docs/architecture/EXTERNAL_FEEDS_INTEGRATION.md` (2000+ lines)

This comprehensive document includes:
- System architecture diagram
- Directory structure
- Core concepts (Provider, Manager, Registry, NormalizedProperty)
- Complete provider interface specifications
- Configuration schema details
- Data normalization specifications
- Caching strategy
- Multi-tenancy design
- Error handling strategy
- Provider implementation guide with examples
- Testing patterns
- API response examples

---

## 10. Current Configuration Options

### Database Level

On `Pwb::Website` model:

```ruby
# Enable/disable
website.external_feed_enabled = true/false
website.external_feed_provider = "resales_online"

# Configuration JSON
website.external_feed_config = {
  # Required by Resales Online
  "api_key" => "...",
  "api_id_sales" => "...",
  
  # Optional
  "api_id_rentals" => "...",
  "p1_constant" => "...",
  "default_country" => "Spain",
  "image_count" => 0,
  
  # Cache TTLs (seconds)
  "cache_ttl_search" => 3600,
  "cache_ttl_property" => 86400,
  "cache_ttl_similar" => 21600,
  "cache_ttl_static" => 604800,
  
  # Defaults
  "results_per_page" => 24,
  "default_locale" => "en",
  "supported_locales" => ["en", "es", "fr", "de", "nl"],
  
  # Optional: Custom locations and property types
  "locations" => [...],
  "property_types" => [...],
  
  # Optional: Feature mappings
  "features" => {...}
}
```

### Search Parameters (Controller Level)

Accepted by external listings search:
- `listing_type` (sale/rental)
- `location` (string)
- `min_price`, `max_price` (integer)
- `min_bedrooms`, `max_bedrooms` (integer)
- `min_bathrooms`, `max_bathrooms` (integer)
- `min_area`, `max_area` (integer - sqm)
- `sort` (price_asc, price_desc, newest, updated)
- `page` (integer)
- `per_page` (integer)
- `property_types[]` (array of codes)
- `features[]` (array of feature names)

### Filter Options (API Level)

The controller provides `/external_listings/filters` endpoint returning:
```json
{
  "locations": [...],
  "property_types": [...],
  "listing_types": [
    {"value": "sale", "label": "For Sale"},
    {"value": "rental", "label": "For Rent"}
  ],
  "sort_options": [...],
  "bedrooms": [...],
  "bathrooms": [...]
}
```

---

## 11. Key Files Summary

| File | Purpose | Key Classes/Methods |
|------|---------|-------------------|
| `/app/models/pwb/website.rb` | Website model | `external_feed_enabled?`, `configure_external_feed`, `clear_external_feed_cache` |
| `/app/services/pwb/external_feed/manager.rb` | Main coordinator | `search`, `filter_options`, `locations`, `property_types` |
| `/app/controllers/pwb/site/external_listings_controller.rb` | Frontend actions | `index`, `show`, `filters`, `locations` |
| `/app/controllers/site_admin/external_feeds_controller.rb` | Admin configuration | `show`, `update`, `test_connection` |
| `/app/services/pwb/external_feed/base_provider.rb` | Provider interface | Abstract methods |
| `/app/services/pwb/external_feed/providers/resales_online.rb` | Resales Online impl | Concrete implementation |
| `/app/services/pwb/external_feed/registry.rb` | Provider registry | `register`, `find`, `available_providers` |
| `/app/services/pwb/external_feed/normalized_property.rb` | Property struct | 80+ attributes + helper methods |
| `/app/services/pwb/external_feed/normalized_search_result.rb` | Search result wrapper | Pagination, error handling |
| `/app/services/pwb/external_feed/cache_store.rb` | Caching layer | Multi-level TTL strategy |
| `/config/initializers/external_feeds.rb` | Provider registration | `to_prepare` hook for registration |
| `/docs/admin/external_feeds.md` | Admin guide | Configuration instructions |
| `/docs/architecture/EXTERNAL_FEEDS_INTEGRATION.md` | Architecture | Complete system design |
| `/db/migrate/20260101211558_add_external_feed_to_websites.rb` | Migration | Schema creation |
| `/spec/requests/site_admin/external_feeds_spec.rb` | Admin tests | Configuration tests |

---

## 12. How Configuration Flows

### Setup Flow

1. **Admin** navigates to `/site_admin/external_feed`
2. **Controller** loads available providers via Registry
3. **Form** displays provider-specific config fields
4. **Admin** enters credentials and settings
5. **Controller** validates and saves to `external_feed_config` JSON column
6. **Cache** is invalidated if enabled
7. **Test Connection** can verify credentials work

### Request Flow

1. **User** requests `/external_listings?location=Marbella&min_price=100000`
2. **Controller** extracts search params
3. **Manager** receives search with params + config
4. **Manager** checks cache first (1-hour TTL)
5. **Manager** delegates to Provider if not cached
6. **Provider** builds API request using config
7. **Provider** normalizes response to NormalizedProperty objects
8. **Manager** returns NormalizedSearchResult
9. **Controller** passes to view with filter_options
10. **View** renders property cards + filter form

### Filter Discovery Flow

1. **User** loads search page
2. **JS** calls `/external_listings/filters`
3. **Controller** calls `external_feed.filter_options(locale: I18n.locale)`
4. **Manager** aggregates:
   - Dynamic: `locations()` and `property_types()` from provider
   - Static: listing_types, sort_options, bedrooms, bathrooms
5. **JSON** response returned with all available options

---

## 13. What's Already Configured

### Resales Online Provider

The system is fully set up for Resales Online:

**Requirements:**
- API Key
- API ID (Sales)
- API ID (Rentals) - optional, falls back to Sales ID

**Default Locations:**
- 20 Costa del Sol cities (Marbella, Estepona, etc.)

**Default Property Types:**
- 4 main categories with subtypes
  - Apartments (with floor-level variants)
  - Houses (with style variants)
  - Plots/Land
  - Commercial

**Languages Supported:**
- English, Spanish, German, French, Dutch, Danish, Russian, Swedish, Polish, Norwegian, Turkish

**API Endpoints:**
- Search: `https://webapi.resales-online.com/WebApi/V6/SearchProperties.php`
- Rentals: `https://webapi.resales-online.com/WebApi/V5-2/SearchProperties.php`
- Details: `https://webapi.resales-online.com/WebApi/V6/PropertyDetails.php`

**Features Supported:**
- Property features extracted from API response
- Features organized by category (Views, Pool, etc.)
- Energy ratings and CO2 data
- Virtual tours
- Community fees and IBI tax extraction

---

## 14. Extension Points

If you want to extend configuration:

### Add Filter Options

**In Manager.filter_options():**
```ruby
def filter_options(params = {})
  {
    # ... existing options ...
    price_ranges: [
      { value: "0-250000", label: "Up to €250k" },
      { value: "250000-500000", label: "€250k - €500k" },
      # ... add more
    ]
  }
end
```

### Add Configuration Fields

**In ExternalFeedsController.provider_config_fields():**
```ruby
when :resales_online
  [
    # ... existing fields ...
    {
      key: :new_setting,
      label: "New Setting",
      type: :text,
      required: false,
      help: "Description"
    }
  ]
```

### Add Search Parameters

**In ExternalListingsController.search_params():**
```ruby
permitted = params.permit(
  # ... existing params ...
  :your_new_param
)
```

### Add Provider

**Create `/app/services/pwb/external_feed/providers/my_provider.rb`**
Register in `/config/initializers/external_feeds.rb`

---

## Summary

The external feed configuration system is:

1. **Storage-wise**: Flexible JSON columns on Website model
2. **Architecture-wise**: Provider pattern with registry and manager
3. **Configuration-wise**: Provider-specific with required keys
4. **Filter-wise**: Mix of static and dynamically-loaded options
5. **Admin-wise**: GUI for configuration with password masking and test connection
6. **Frontend-wise**: API endpoints for filter discovery and search

All configuration is **multi-tenant aware** - each website has isolated config and cache.

