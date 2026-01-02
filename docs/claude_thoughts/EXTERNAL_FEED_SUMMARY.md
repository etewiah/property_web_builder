# External Feed Configuration System - Executive Summary

## What This System Does

PropertyWebBuilder includes a **complete external property feed integration system** that allows websites to display property listings from third-party providers (like Resales Online) alongside or instead of locally-managed properties.

Key capability: **Real-time property fetching with caching, filtering, and search** - all multi-tenant aware.

---

## How Configuration is Stored

### Location: `pwb_websites` Table

Three columns store everything needed:

```ruby
external_feed_enabled: boolean       # Master on/off switch
external_feed_provider: string       # Provider name (e.g., "resales_online")
external_feed_config: json          # Provider-specific settings
```

### What Goes in the Config

The JSON config contains:

**Required Fields (Resales Online example):**
- `api_key` - API credentials
- `api_id_sales` - API ID for sales listings

**Optional Fields:**
- `api_id_rentals` - Separate ID for rentals (falls back to sales ID)
- `p1_constant` - Provider-specific constant
- `default_country` - Default location
- `image_count` - Number of images to fetch (0 = all)

**Cache Configuration:**
- `cache_ttl_search` - Search results cache (default: 3600 seconds)
- `cache_ttl_property` - Property details cache (default: 86400 seconds)
- `cache_ttl_similar` - Similar properties cache (default: 21600 seconds)
- `cache_ttl_static` - Static data cache (default: 604800 seconds)

**Defaults:**
- `results_per_page` - How many results per page (default: 24)
- `default_locale` - Default language (default: "en")
- `supported_locales` - Languages to support (array)

**Optional Custom Data:**
- `locations` - Custom location list (falls back to provider defaults)
- `property_types` - Custom property type list
- `features` - Feature name mappings

---

## The Filter Options System

The `Manager.filter_options()` method returns all available search filters:

### What It Returns

```ruby
{
  locations: [          # DYNAMIC from provider
    {value: "Marbella", label: "Marbella"},
    ...
  ],
  property_types: [     # DYNAMIC from provider
    {value: "1-1", label: "Apartment", subtypes: [...]},
    {value: "2-1", label: "House", subtypes: [...]},
    ...
  ],
  listing_types: [      # STATIC - hardcoded
    {value: "sale", label: "For Sale"},
    {value: "rental", label: "For Rent"}
  ],
  sort_options: [       # STATIC - hardcoded
    {value: "price_asc", label: "Price (Low to High)"},
    {value: "price_desc", label: "Price (High to Low)"},
    {value: "newest", label: "Newest First"},
    {value: "updated", label: "Recently Updated"}
  ],
  bedrooms: [           # STATIC - 1+ through 6+
    {value: "1", label: "1+"},
    {value: "2", label: "2+"},
    ...
  ],
  bathrooms: [          # STATIC - 1+ through 4+
    {value: "1", label: "1+"},
    ...
  ]
}
```

### How It's Used

- **Frontend Search Form:** Form fields pull from these options
- **AJAX Endpoint:** `/external_listings/filters` returns this JSON
- **Individual Endpoints:** 
  - `/external_listings/locations` - just locations
  - `/external_listings/property_types` - just property types

---

## Admin Interface

### Location
- `/site_admin/external_feed` - Configuration page

### What Admins Can Do

1. **Enable/Disable** - Toggle external feeds on/off
2. **Select Provider** - Choose from registered providers
3. **Configure Credentials** - Enter API keys and settings specific to provider
4. **Test Connection** - Verify credentials work with provider
5. **Clear Cache** - Force refresh of external data

### How It Works

- Page shows provider-specific configuration fields
- Passwords are masked when displayed (shown as •••••)
- When updating, masked passwords are preserved (not overwritten)
- Configuration is saved to `external_feed_config` JSON column
- Cache is automatically cleared when settings change

---

## Search & Filter Flow

### Search Request
```
User searches: /external_listings?location=Marbella&min_price=100000
    ↓
Controller extracts: {location: "Marbella", min_price: 100000, ...}
    ↓
Manager normalizes: converts to integers, sets defaults
    ↓
Cache checks: do we have this search cached?
    ↓
Provider searches: calls Resales Online API (if not cached)
    ↓
Results normalized: API response → NormalizedProperty objects
    ↓
NormalizedSearchResult returned with properties, pagination info
    ↓
View displays results
```

### Filter Discovery
```
JavaScript calls: /external_listings/filters
    ↓
Controller calls: external_feed.filter_options(locale: I18n.locale)
    ↓
Manager aggregates:
  - Calls provider.locations() → cached 1 week
  - Calls provider.property_types() → cached 1 week
  - Returns hardcoded listing_types, sort_options, bedrooms, bathrooms
    ↓
JSON returned with all filter options
    ↓
JavaScript populates form fields
```

---

## How External Listings Controller Uses Filters

### Endpoint: GET /external_listings/filters

```ruby
def filters
  @filter_options = external_feed.filter_options(locale: I18n.locale)
  render json: @filter_options
end
```

Returns JSON with all available filter options.

### Endpoint: GET /external_listings/locations

```ruby
def locations
  @locations = external_feed.locations(locale: I18n.locale)
  render json: @locations
end
```

Returns just locations array.

### Endpoint: GET /external_listings/property_types

```ruby
def property_types
  @property_types = external_feed.property_types(locale: I18n.locale)
  render json: @property_types
end
```

Returns just property types array.

### Search Parameters Accepted

In `/external_listings?...`:
- `listing_type` - sale or rental
- `location` - city name
- `min_price`, `max_price` - price range
- `min_bedrooms`, `max_bedrooms` - bedroom count
- `min_bathrooms` - minimum bathrooms
- `min_area`, `max_area` - built area in sqm
- `sort` - price_asc, price_desc, newest, updated
- `page` - page number
- `per_page` - results per page
- `property_types[]` - array of type codes
- `features[]` - array of feature names

---

## Existing Admin Interfaces

### Configuration Page
**File:** `/app/views/site_admin/external_feeds/show.html.erb`

Displays:
- List of available providers (from Registry)
- Current provider selection
- Configuration form with provider-specific fields
- Current configuration values (with masked passwords)
- Test Connection button
- Clear Cache button

### Configuration Form Fields (Resales Online)

```ruby
API Key               (password field, required)
API ID (Sales)        (text field, required)
API ID (Rentals)      (text field, optional)
P1 Constant           (text field, optional)
```

Each field shows:
- Label
- Input type (text, password)
- Whether it's required
- Help text explaining what it is

### Admin Actions

1. **Show Page** - GET /site_admin/external_feed
2. **Update Config** - PATCH /site_admin/external_feed
3. **Test Connection** - POST /site_admin/external_feed/test_connection
4. **Clear Cache** - POST /site_admin/external_feed/clear_cache

---

## Provider System

### How Providers Are Registered

At Rails boot, initializer registers providers:

```ruby
# /config/initializers/external_feeds.rb
Rails.application.config.to_prepare do
  Pwb::ExternalFeed::Registry.register(
    Pwb::ExternalFeed::Providers::ResalesOnline
  )
end
```

Registry maintains list of available providers.

### Current Providers

**Resales Online** (Implemented)
- Provider name: `resales_online`
- Region: Spain (Costa del Sol)
- Languages: EN, ES, DE, FR, NL, DA, RU, SV, PL, NO, TR
- Features: Full search, property details, similar properties

### Provider Interface

All providers must inherit from `BaseProvider` and implement:

```ruby
def search(params)                    # → NormalizedSearchResult
def find(reference, params)           # → NormalizedProperty
def similar(property, params)         # → Array<NormalizedProperty>
def locations(params)                 # → Array<{value, label}>
def property_types(params)            # → Array<{value, label, subtypes?}>
def available?                        # → Boolean

protected
def required_config_keys              # → Array<Symbol>
```

---

## Data Normalization

### What Gets Returned

All providers return data in standard formats:

**NormalizedProperty:**
- reference, title, description
- property_type, property_subtype
- location (country, region, area, city, lat/lon)
- listing_type (:sale or :rental)
- status (:available, :reserved, :sold, :rented, :unavailable)
- price (in cents), currency
- bedrooms, bathrooms, built_area, plot_area, terrace_area
- images (array of URLs)
- features (flat array and organized by category)
- energy ratings, virtual tour URL
- 80+ total attributes

**NormalizedSearchResult:**
- properties (array of NormalizedProperty)
- total_count, page, per_page, total_pages
- query_params (the search criteria used)
- provider, fetched_at, error (if failed)
- Helper methods: first_page?, last_page?, next_page, prev_page, results_range

---

## Caching Strategy

### Multi-Level Cache

| Operation | TTL | Cache Key |
|-----------|-----|-----------|
| Search | 1 hour | `pwb:external_feed:1:resales_online:search:{hash}` |
| Property | 24 hours | `pwb:external_feed:1:resales_online:property:{hash}` |
| Similar | 6 hours | `pwb:external_feed:1:resales_online:similar:{hash}` |
| Locations | 1 week | `pwb:external_feed:1:resales_online:locations:{hash}` |
| Property Types | 1 week | `pwb:external_feed:1:resales_online:property_types:{hash}` |

### Cache Invalidation

When admin updates configuration:
1. Configuration saved to database
2. `website.external_feed.invalidate_cache` called
3. All cache keys for this website deleted
4. Next request will fetch fresh data

---

## Multi-Tenancy

Each website has:
- **Own configuration** (external_feed_config JSON)
- **Own provider choice** (external_feed_provider string)
- **Own cache namespace** (website_id in cache key)
- **Own credentials** (secure in JSON column)

Websites are completely isolated - no cross-tenant data leakage.

---

## What Configuration Options Already Exist

### Database Schema
- `external_feed_enabled` - Boolean toggle
- `external_feed_provider` - String (provider name)
- `external_feed_config` - JSON blob with provider config

### Manager Filter Options
- locations (dynamic)
- property_types (dynamic)
- listing_types (static: sale, rental)
- sort_options (static: 4 sort orders)
- bedrooms (static: 1+ to 6+)
- bathrooms (static: 1+ to 4+)

### Controller Endpoints
- GET /external_listings (search with form)
- GET /external_listings/:reference (property details)
- GET /external_listings/:reference/similar (similar properties)
- GET /external_listings/filters (JSON - all filter options)
- GET /external_listings/locations (JSON - locations only)
- GET /external_listings/property_types (JSON - types only)

### Admin Endpoints
- GET /site_admin/external_feed (configuration page)
- PATCH /site_admin/external_feed (save configuration)
- POST /site_admin/external_feed/test_connection
- POST /site_admin/external_feed/clear_cache

### Search Parameters Accepted
- listing_type, location, min/max_price
- min/max_bedrooms, min/max_bathrooms
- min/max_area, sort, page, per_page
- property_types[], features[]

---

## Extension Points

If you want to add more configuration:

1. **Add filter options in Manager** - add to filter_options() hash
2. **Add config fields in Admin** - add to provider_config_fields() method
3. **Add search parameters** - permit in controller, handle in manager
4. **Add provider** - create new provider class, register it
5. **Add cache options** - add new TTL config keys
6. **Add feature mappings** - store in external_feed_config["features"]

---

## File Locations (Key Files)

**Models:**
- `/app/models/pwb/website.rb` - Website model with external_feed methods

**Services:**
- `/app/services/pwb/external_feed/manager.rb` - Main coordinator (filter_options here)
- `/app/services/pwb/external_feed/base_provider.rb` - Provider interface
- `/app/services/pwb/external_feed/providers/resales_online.rb` - Resales Online impl
- `/app/services/pwb/external_feed/registry.rb` - Provider registry
- `/app/services/pwb/external_feed/normalized_property.rb` - Property data structure
- `/app/services/pwb/external_feed/normalized_search_result.rb` - Search result wrapper
- `/app/services/pwb/external_feed/cache_store.rb` - Caching layer

**Controllers:**
- `/app/controllers/pwb/site/external_listings_controller.rb` - Frontend (filters, search)
- `/app/controllers/site_admin/external_feeds_controller.rb` - Admin configuration

**Configuration:**
- `/config/initializers/external_feeds.rb` - Provider registration
- `/db/migrate/20260101211558_add_external_feed_to_websites.rb` - Schema

**Documentation:**
- `/docs/admin/external_feeds.md` - Admin user guide
- `/docs/architecture/EXTERNAL_FEEDS_INTEGRATION.md` - Complete architecture (2000+ lines)

**Tests:**
- `/spec/requests/site_admin/external_feeds_spec.rb` - Admin tests
- `/spec/services/pwb/external_feed/manager_spec.rb` - Manager tests
- `/spec/services/pwb/external_feed/providers/resales_online_spec.rb` - Provider tests

---

## Quick Start

### For Admins
1. Navigate to `/site_admin/external_feed`
2. Select provider (Resales Online)
3. Enter API credentials
4. Click Test Connection
5. Click Save

### For Developers Adding a Provider
1. Create `/app/services/pwb/external_feed/providers/my_provider.rb`
2. Inherit from `BaseProvider`
3. Implement all required methods
4. Register in `/config/initializers/external_feeds.rb`
5. Add config fields to ExternalFeedsController#provider_config_fields
6. Test with credentials
7. Document configuration

### For Frontend Developers
1. Call `/external_listings/filters` to get all filter options
2. Call `/external_listings?location=...&min_price=...` to search
3. Call `/external_listings/:reference` to view details
4. Use NormalizedProperty attributes to display information

---

## Summary

The external feed configuration system is:

✅ **Complete** - Fully functional with Resales Online provider  
✅ **Flexible** - JSON config, provider pattern, extensible  
✅ **Multi-tenant** - Each website isolated  
✅ **Well-cached** - Multiple TTL levels for performance  
✅ **Documented** - Extensive architecture and admin documentation  
✅ **Secure** - API keys stored securely, password masking  
✅ **Tested** - Unit and integration tests included

It supports:
- Real-time property fetching
- Multi-language support
- Property filtering and search
- Similar property recommendations
- Admin configuration interface
- Cache management
- Error handling and graceful degradation

All configuration is stored in the database and can be managed through the web interface or programmatically via the API.

