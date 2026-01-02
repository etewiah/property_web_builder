# External Listings Feature - File Structure & Quick Reference

## File Structure Map

### Controllers
```
app/controllers/
├── pwb/site/
│   └── external_listings_controller.rb       # Frontend: search, show, similar, filters
└── site_admin/
    └── external_feeds_controller.rb          # Admin: config, test, cache clear
```

**Key Controller Methods:**
- `ExternalListingsController#index` - Search/browse results
- `ExternalListingsController#show` - Property detail page
- `ExternalListingsController#similar` - Similar properties (AJAX)
- `ExternalListingsController#filters`, `#locations`, `#property_types` - JSON endpoints
- `ExternalFeedsController#show` - Configuration form
- `ExternalFeedsController#update` - Save configuration
- `ExternalFeedsController#test_connection` - Verify API connectivity
- `ExternalFeedsController#clear_cache` - Clear cached results

---

### Views
```
app/views/
├── pwb/site/external_listings/
│   ├── index.html.erb                        # Search results page with modals
│   ├── show.html.erb                         # Property detail page
│   ├── unavailable.html.erb                  # Property no longer available
│   ├── _search_form.html.erb                 # Filter sidebar component
│   ├── _property_card.html.erb               # Grid card component
│   ├── _pagination.html.erb                  # Pagination component
│   └── _similar.html.erb                     # Similar properties grid
└── site_admin/external_feeds/
    └── show.html.erb                         # Admin feed configuration
```

**View Component Hierarchy:**
```
index.html.erb
├── _search_form.html.erb (sidebar)
└── _property_card.html.erb × N (grid items)
    └── Uses images, price, location, features

show.html.erb
├── Image gallery with thumbnails
├── Property details
├── Features, energy, map
├── Price sidebar with contact buttons
└── _similar.html.erb
    └── _property_card.html.erb × 6

_pagination.html.erb
├── Mobile: Previous/Next
└── Desktop: Page numbers with smart window
```

---

### Services & Business Logic
```
app/services/pwb/external_feed/
├── external_feed.rb                          # Module definition
├── manager.rb                                # Main orchestrator
├── base_provider.rb                          # Abstract provider class
├── registry.rb                               # Provider registry pattern
├── normalized_property.rb                    # Property data structure
├── normalized_search_result.rb               # Search result wrapper
├── cache_store.rb                            # Caching layer
├── errors.rb                                 # Error classes
└── providers/
    ├── resales_online.rb                     # Resales Online API implementation
    └── [future providers]
```

**Key Service Classes & Methods:**

#### Manager (`manager.rb`)
```ruby
Manager#search(params)          # → NormalizedSearchResult
Manager#find(reference, params) # → NormalizedProperty | nil
Manager#similar(property, params) # → Array<NormalizedProperty>
Manager#locations(params)       # → Array<Hash> [{value, label}]
Manager#property_types(params)  # → Array<Hash> [{value, label}]
Manager#filter_options(params)  # → Hash with all filter options
Manager#enabled?                # → Boolean
Manager#configured?             # → Boolean
```

#### BaseProvider (`base_provider.rb`)
```ruby
BaseProvider#search(params)     # Abstract: must implement
BaseProvider#find(reference, params) # Abstract: must implement
BaseProvider#similar(property, params) # Abstract: must implement
BaseProvider#locations(params)  # Abstract: must implement
BaseProvider#property_types(params) # Abstract: must implement
BaseProvider#available?         # Abstract: must implement
BaseProvider.provider_name      # Class method: must implement (symbol)
BaseProvider.display_name       # Class method: human readable name
```

#### ResalesOnline (`providers/resales_online.rb`)
```ruby
ResalesOnline#search(params)    # Calls SEARCH_URL, normalizes response
ResalesOnline#find(reference, params) # Calls DETAILS_URL
ResalesOnline#similar(property, params) # Searches similar criteria
ResalesOnline#locations(params) # Returns config locations or defaults
ResalesOnline#property_types(params) # Returns config property types
ResalesOnline#available?        # Quick test API call
ResalesOnline.provider_name     # Returns :resales_online
ResalesOnline.display_name      # Returns "Resales Online"
```

#### NormalizedProperty (`normalized_property.rb`)
```ruby
# ~30 attributes across: identification, location, listing, rental,
# property details, features, energy, media, costs, metadata

NormalizedProperty#formatted_price  # Currency-formatted
NormalizedProperty#main_image       # First image URL
NormalizedProperty#available?       # Status check
NormalizedProperty#price_reduced?   # Price comparison
NormalizedProperty#to_h             # Hash for JSON
```

#### NormalizedSearchResult (`normalized_search_result.rb`)
```ruby
NormalizedSearchResult#properties   # Array<NormalizedProperty>
NormalizedSearchResult#current_page # Current page number
NormalizedSearchResult#total_pages  # Total pages
NormalizedSearchResult#next_page    # Next page number or nil
NormalizedSearchResult#prev_page    # Previous page number or nil
NormalizedSearchResult#results_range # "X-Y of Z" string
NormalizedSearchResult#empty?, #any? # Collection checks
NormalizedSearchResult#error?       # Search error status
NormalizedSearchResult#to_h, #as_json # Serialization
```

---

### JavaScript/Stimulus
```
app/javascript/controllers/
└── filter_controller.js                      # Filter form controller

app/javascript/
└── [other controllers - Vue deprecated]
```

**FilterController Methods:**
```javascript
FilterController#togglePanel()      # Show/hide filter sidebar
FilterController#showPanel()        # Show filter sidebar
FilterController#hidePanel()        # Hide filter sidebar
FilterController#submit()           # Submit filter form
FilterController#submitOnChange()   # Auto-submit on filter change
FilterController#debounceSubmit()   # Debounced auto-submit
FilterController#clear()            # Reset all filters
FilterController#updateCount()      # Update active filter count
```

**Targets & Values:**
- Targets: `panel`, `form`, `count`, `input`
- Values: `submitOnChange` (boolean), `debounce` (number, ms)

---

### Models & Concerns
```
app/models/concerns/
└── external_image_support.rb                 # Image handling support
```

**Website Model Extensions:**
```ruby
# On Pwb::Website:
website.external_feed                    # → Manager instance
website.external_feed_enabled?           # → Boolean
website.external_feed_provider           # → String (provider name)
website.external_feed_config             # → Hash (provider config)
```

---

### Configuration & Initialization
```
config/
├── routes.rb                                 # Route definitions
├── initializers/
│   └── external_feeds.rb                     # Provider registration
└── locales/
    ├── en.yml, es.yml, fr.yml, etc.         # Translations (distributed)
    └── [external_feed keys - check inline]
```

**Routes Summary:**
```ruby
# Frontend routes
GET  /external_listings              # Search results
GET  /external_listings/search       # Alias for search
GET  /external_listings/:reference   # Property detail
GET  /external_listings/:reference/similar # Similar properties
GET  /external_listings/locations    # JSON locations
GET  /external_listings/property_types # JSON property types
GET  /external_listings/filters      # JSON filter options

# Admin routes
GET  /site_admin/external_feed       # Configuration form
PATCH /site_admin/external_feed      # Update configuration
POST /site_admin/external_feed/test_connection # Test API
POST /site_admin/external_feed/clear_cache # Clear cache
```

---

### Tests & Specs
```
spec/
├── requests/site/
│   └── external_listings_spec.rb             # Integration tests
├── requests/site_admin/
│   └── external_feeds_spec.rb                # Admin integration tests
├── services/pwb/external_feed/
│   ├── [unit tests for services]
│   └── providers/
│       └── [provider unit tests]
└── models/concerns/
    └── external_image_support_spec.rb        # Image support tests
```

---

### Documentation
```
docs/
├── admin/
│   └── external_feeds.md                     # Admin guide
├── seeding/
│   └── external_seed_images.md               # Seed image setup
└── claude_thoughts/
    ├── external_listings_exploration.md      # Detailed exploration (this file)
    └── external_listings_file_structure.md   # Quick reference (this file)
```

---

## Translation Keys Structure

### Current Implementation
Translations are **NOT in centralized YAML files** but rather:
1. **Inline in views** with `t("external_feed.search.title", default: "...")`
2. **Dynamic translations** from provider data
3. **Managed through I18n** with locale parameter

### Key Namespaces Used

```yaml
external_feed:
  search:           # Search page labels
    title, subtitle, filters, listing_type, location, etc.
  listing_type:     # Radio button labels ("For Sale", "For Rent")
  listing_types:    # Dropdown labels ("Buy", "Rent")
  property_types:   # Dynamic property type translations
  features:         # Feature labels (bedrooms, bathrooms, etc.)
  frequency:        # Rental periods (month, week, day)
  sort:             # Sort option labels
  pagination:       # Pagination labels
  breadcrumb:       # Navigation labels
  property:         # Property detail page labels
  status:           # Property status messages
  badges:           # Badge labels
  not_configured:   # Configuration error message
```

### To Find Translation Keys
Use Grep in views:
```bash
grep -r "t(\"external_feed" app/views/pwb/site/external_listings/
```

---

## Key Data Flows

### Search Flow
```
Controller#index
  ↓
Manager#search(params)
  ↓
CacheStore.fetch_data(:search, params)
  ↓ (cache miss)
Provider#search(params)
  ↓
API call (ResalesOnline)
  ↓
normalize_search_results()
  ↓
NormalizedSearchResult (with NormalizedProperty[])
  ↓ (back through cache)
View displays results with pagination
```

### Property Detail Flow
```
Controller#show(reference)
  ↓
Manager#find(reference, params)
  ↓
CacheStore.fetch_data(:property, {reference, ...})
  ↓ (cache miss)
Provider#find(reference, params)
  ↓
API call (ResalesOnline DETAILS_URL)
  ↓
normalize_property()
  ↓
NormalizedProperty (with availability check)
  ↓
Manager#similar(property, params) [parallel]
  ↓
View displays property + similar properties
```

### Filter Options Flow
```
Controller#index
  ↓
Manager#filter_options(locale: I18n.locale)
  ↓
Manager#locations() + Manager#property_types() + sort options
  ↓
CacheStore.fetch_data (for locations & property_types)
  ↓ (cache miss)
Provider#locations() + Provider#property_types()
  ↓
Returns Array<{value:, label:}>
  ↓
Returns combined hash with sort_options
  ↓
View renders _search_form.html.erb with options
```

---

## Performance Considerations

### Caching
- **Search results:** Cached with params as key
- **Property details:** Cached per reference
- **Similar properties:** Cached per reference + limit
- **Locations/Types:** Cached, minimal TTL
- **Invalidation:** Manual via `clear_cache`, or automatic on config update

### Pagination
- Default 24 results per page
- Can be customized via `per_page` param
- Smart pagination display (shows current ±2, first, last)

### Images
- Lazy loading on cards (`loading="lazy"`)
- Image count indicator on cards
- Thumbnail strip on detail page
- Configurable image count in provider config

### API Optimization
- Resales Online V6 for sales, V5-2 for rentals (different endpoints)
- Timeouts: 10s connect, 30s read
- Rate limit handling (429 errors)
- Redirect following for API calls

---

## Provider Integration Points

To add a new provider:

1. **Create Provider Class**
   - Location: `app/services/pwb/external_feed/providers/my_provider.rb`
   - Inherit from `BaseProvider`
   - Implement all abstract methods

2. **Register Provider**
   - Location: `config/initializers/external_feeds.rb`
   - Add: `Pwb::ExternalFeed::Registry.register(Pwb::ExternalFeed::Providers::MyProvider)`

3. **Add Configuration**
   - Update `SiteAdmin::ExternalFeedsController#provider_config_fields`
   - Define required and optional config keys

4. **Add Translations**
   - Ensure property type codes map to translatable keys
   - Use `t("external_feed.property_types.#{type}", default: type.titleize)`

5. **Test Implementation**
   - Add spec in `spec/services/pwb/external_feed/providers/`
   - Implement test for all abstract methods
   - Test API error handling

---

## Quick Links to Key Files

| Purpose | File | Lines |
|---------|------|-------|
| Frontend controller | `controllers/pwb/site/external_listings_controller.rb` | 1-149 |
| Admin controller | `controllers/site_admin/external_feeds_controller.rb` | 1-195 |
| Search results view | `views/pwb/site/external_listings/index.html.erb` | 1-306 |
| Property detail view | `views/pwb/site/external_listings/show.html.erb` | 1-381 |
| Filter form | `views/pwb/site/external_listings/_search_form.html.erb` | 1-192 |
| Property card | `views/pwb/site/external_listings/_property_card.html.erb` | 1-125 |
| Pagination | `views/pwb/site/external_listings/_pagination.html.erb` | 1-134 |
| Manager service | `services/pwb/external_feed/manager.rb` | 1-200+ |
| Base provider | `services/pwb/external_feed/base_provider.rb` | 1-100+ |
| Resales provider | `services/pwb/external_feed/providers/resales_online.rb` | 1-400+ |
| Normalized property | `services/pwb/external_feed/normalized_property.rb` | 1-200+ |
| Search result | `services/pwb/external_feed/normalized_search_result.rb` | 1-198 |
| Filter controller | `javascript/controllers/filter_controller.js` | 1-102 |
| Initializer | `config/initializers/external_feeds.rb` | 1-27 |
| Routes | `config/routes.rb` | [external_listings routes] |

