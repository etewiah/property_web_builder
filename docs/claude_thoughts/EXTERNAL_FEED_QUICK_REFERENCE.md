# External Feed Configuration - Quick Reference Guide

## Configuration Storage

```
Website Model (pwb_websites table)
├── external_feed_enabled: BOOLEAN (default: false)
├── external_feed_provider: STRING (e.g., "resales_online")
└── external_feed_config: JSON (provider-specific settings)
```

## Configuration JSON Structure

```json
{
  "api_key": "secret_key",
  "api_id_sales": "1234",
  "api_id_rentals": "5678",
  "p1_constant": "1014359",
  "default_country": "Spain",
  "image_count": 0,
  "cache_ttl_search": 3600,
  "cache_ttl_property": 86400,
  "results_per_page": 24,
  "default_locale": "en",
  "supported_locales": ["en", "es", "fr", "de", "nl"]
}
```

## Filter Options Architecture

```
Manager.filter_options()
├── locations[]          (DYNAMIC - from provider)
├── property_types[]     (DYNAMIC - from provider with subtypes)
├── listing_types[]      (STATIC - ["sale", "rental"])
├── sort_options[]       (STATIC - ["price_asc", "price_desc", "newest", "updated"])
├── bedrooms[]           (STATIC - [1+, 2+, 3+, 4+, 5+, 6+])
└── bathrooms[]          (STATIC - [1+, 2+, 3+, 4+])
```

## Search Parameter Flow

```
ExternalListingsController.search_params()
  ↓
Accepted: listing_type, location, min_price, max_price, 
          min_bedrooms, max_bedrooms, min_bathrooms, max_bathrooms,
          min_area, max_area, sort, page, per_page,
          property_types[], features[]
  ↓
Manager.search(normalized_params)
  ↓
Cache.fetch_data(:search, params)
  ↓
Provider.search() or cached result
  ↓
NormalizedSearchResult(properties[], total_count, page, per_page, ...)
```

## Admin Interface

```
/site_admin/external_feed
├── Show Page
│   ├── List available providers (Registry.available_providers)
│   ├── Show provider-specific config fields
│   └── Display current feed status
├── Update Action
│   ├── Validate params
│   ├── Save to external_feed_config
│   ├── Invalidate cache
│   └── Redirect with notice
├── Test Connection Action
│   ├── Feed.search(page: 1, per_page: 1)
│   └── Show success/error message
└── Clear Cache Action
    └── CacheStore.invalidate_all()
```

## Key Classes & Methods

### Website Model
```ruby
website.external_feed_enabled?              # Boolean check
website.external_feed                       # Get Manager instance
website.configure_external_feed(provider:, config:, enabled:)
website.disable_external_feed
website.clear_external_feed_cache
```

### Manager
```ruby
manager = Manager.new(website)
manager.search(params)                      # → NormalizedSearchResult
manager.find(reference, params)             # → NormalizedProperty
manager.similar(property, params)           # → Array<NormalizedProperty>
manager.filter_options(params)              # → Hash of filter arrays
manager.locations(params)                   # → Array<{value, label}>
manager.property_types(params)              # → Array<{value, label, subtypes}>
manager.enabled?                            # Boolean
manager.configured?                         # Boolean
manager.invalidate_cache
manager.provider_name                       # String
manager.provider_display_name               # String
```

### NormalizedProperty
```ruby
property.reference              # Provider's unique ID
property.title, property.description
property.property_type          # "apartment", "villa", "house", etc.
property.city, property.region, property.country
property.latitude, property.longitude
property.listing_type           # :sale or :rental
property.status                 # :available, :reserved, :sold, :rented, :unavailable
property.price                  # Integer (cents)
property.currency               # "EUR"
property.bedrooms, property.bathrooms
property.built_area, property.plot_area (sqm)
property.images                 # Array<{url, caption, position}>
property.features               # Array<String>
property.features_by_category   # Hash<Category, Array<Features>>
property.formatted_price        # "EUR 450,000"
property.available?             # Boolean
property.price_reduced?         # Boolean
property.price_reduction_percent
property.to_h                   # Convert to hash
```

### NormalizedSearchResult
```ruby
result.properties               # Array<NormalizedProperty>
result.total_count
result.page, result.per_page, result.total_pages
result.query_params
result.provider
result.error                    # Error message or nil
result.empty?, result.any?
result.first_page?, result.last_page?
result.next_page, result.prev_page
result.results_range            # "1-24 of 150"
result.to_h, result.as_json()
```

### Registry
```ruby
Registry.register(ProviderClass)
Registry.find(provider_name)        # → ProviderClass
Registry.registered?(name)
Registry.available_providers        # → [Symbol]
```

## Controller Endpoints

### Frontend Routes
```
GET  /external_listings                     # Search (with filters)
GET  /external_listings?location=...        # Search with params
GET  /external_listings/:reference          # Property details
GET  /external_listings/:reference/similar  # Similar properties
GET  /external_listings/locations           # Filter: locations JSON
GET  /external_listings/property_types      # Filter: property types JSON
GET  /external_listings/filters             # Filter: all options JSON
```

### Admin Routes
```
GET  /site_admin/external_feed              # Configuration page
PATCH /site_admin/external_feed             # Update configuration
POST /site_admin/external_feed/test_connection
POST /site_admin/external_feed/clear_cache
```

## Cache TTLs

| Operation | Default | Config Key |
|-----------|---------|------------|
| Search results | 1 hour | cache_ttl_search |
| Property details | 24 hours | cache_ttl_property |
| Similar properties | 6 hours | cache_ttl_similar |
| Locations/Types | 1 week | cache_ttl_static |

Cache key format: `pwb:external_feed:{website_id}:{provider}:{operation}:{params_hash}`

## Property Type Normalization

**Valid Values:**
- apartment, apartment_ground, apartment_middle, apartment_top
- penthouse
- house, villa, townhouse, semi_detached
- bungalow
- finca (country house)
- land (plot)
- commercial
- garage (parking)
- other

## Provider System

```
BaseProvider (abstract)
  ├── ResalesOnline (implemented)
  ├── KyeroProvider (planned)
  └── ThinkSpainProvider (planned)

Registry maintains singleton of all available providers
Manager loads provider class from Registry and instantiates it
```

### Required Provider Methods

```ruby
class MyProvider < BaseProvider
  def self.provider_name           # :my_provider
  def self.display_name            # "My Provider"
  
  def search(params)               # → NormalizedSearchResult
  def find(reference, params)      # → NormalizedProperty
  def similar(property, params)    # → Array<NormalizedProperty>
  def locations(params)            # → Array<{value, label}>
  def property_types(params)       # → Array<{value, label, subtypes}>
  def available?                   # → Boolean
  
  protected
  def required_config_keys         # → Array<Symbol>
end
```

## Resales Online Specifics

**Provider Name:** `resales_online`

**Required Config:**
- `api_key` - API key from Resales Online
- `api_id_sales` - API ID for sales listings

**Optional Config:**
- `api_id_rentals` - API ID for rentals (uses sales ID if not set)
- `p1_constant` - P1 parameter (default: "1014359")
- `default_country` - Country name (default: "Spain")
- `image_count` - Number of images (0 = all)

**Languages:** EN, ES, DE, FR, NL, DA, RU, SV, PL, NO, TR

**Default Locations:** 20 Costa del Sol cities

**Default Property Types:** 
- Apartments (with floor variants)
- Houses (with style variants)
- Plots/Land
- Commercial

**API Endpoints:**
- Search V6: https://webapi.resales-online.com/WebApi/V6/SearchProperties.php
- Search V5: https://webapi.resales-online.com/WebApi/V5-2/SearchProperties.php (rentals)
- Details: https://webapi.resales-online.com/WebApi/V6/PropertyDetails.php

## Error Handling

**Custom Exceptions:**
```ruby
Pwb::ExternalFeed::Error
  ├── ConfigurationError
  ├── AuthenticationError
  ├── RateLimitError
  ├── ProviderUnavailableError
  ├── PropertyNotFoundError
  └── InvalidResponseError
```

## Multi-Tenancy

- Each website has isolated `external_feed_config`
- Each website has isolated cache namespace
- Each website can use different provider
- Each website can have different credentials
- Provider is tenant-aware via Manager initialization with website

## File Locations

**Models:**
- `/app/models/pwb/website.rb`

**Services:**
- `/app/services/pwb/external_feed/manager.rb`
- `/app/services/pwb/external_feed/base_provider.rb`
- `/app/services/pwb/external_feed/providers/resales_online.rb`
- `/app/services/pwb/external_feed/registry.rb`
- `/app/services/pwb/external_feed/normalized_property.rb`
- `/app/services/pwb/external_feed/normalized_search_result.rb`
- `/app/services/pwb/external_feed/cache_store.rb`
- `/app/services/pwb/external_feed/errors.rb`

**Controllers:**
- `/app/controllers/pwb/site/external_listings_controller.rb`
- `/app/controllers/site_admin/external_feeds_controller.rb`

**Configuration:**
- `/config/initializers/external_feeds.rb`

**Database:**
- `/db/migrate/20260101211558_add_external_feed_to_websites.rb`

**Documentation:**
- `/docs/admin/external_feeds.md` - Admin guide
- `/docs/architecture/EXTERNAL_FEEDS_INTEGRATION.md` - Complete architecture

**Tests:**
- `/spec/requests/site_admin/external_feeds_spec.rb`
- `/spec/services/pwb/external_feed/manager_spec.rb`
- `/spec/services/pwb/external_feed/providers/resales_online_spec.rb`

## Common Operations

### Setup External Feed for Website

```ruby
website = Pwb::Website.find(1)
website.configure_external_feed(
  provider: :resales_online,
  config: {
    api_key: "xxx",
    api_id_sales: "123",
    api_id_rentals: "456"
  },
  enabled: true
)
```

### Search Properties

```ruby
feed = website.external_feed
result = feed.search(
  listing_type: :sale,
  location: "Marbella",
  min_price: 100000,
  max_price: 500000,
  min_bedrooms: 2,
  page: 1
)
result.properties.each { |prop| puts prop.title }
```

### Get Filter Options

```ruby
options = feed.filter_options(locale: :en)
# Returns { locations: [...], property_types: [...], ... }
```

### Find Single Property

```ruby
property = feed.find("R3096106", locale: :en, listing_type: :sale)
puts property.formatted_price
puts property.full_location
```

### Get Similar Properties

```ruby
similar = feed.similar(property, limit: 8, locale: :en)
```

### Clear Cache

```ruby
website.clear_external_feed_cache
# or
feed.invalidate_cache
```

## Extension Checklist

To add a new provider:

- [ ] Create `/app/services/pwb/external_feed/providers/my_provider.rb`
- [ ] Inherit from `BaseProvider`
- [ ] Implement all required methods
- [ ] Add property type normalization mapping
- [ ] Add locale code mapping
- [ ] Implement error handling
- [ ] Register in `/config/initializers/external_feeds.rb`
- [ ] Add `provider_config_fields` case in ExternalFeedsController
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Document configuration requirements
- [ ] Test with real credentials

