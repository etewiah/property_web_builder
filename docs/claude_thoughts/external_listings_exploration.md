# External Listings Feature Exploration

## Overview

The external listings feature allows websites to display properties from external feed providers (currently Resales Online for Spanish properties). It's a complete property search and display system with filters, pagination, translations, and caching.

## Architecture

### High-Level Flow

1. **Controller** receives search/browse requests
2. **Manager** (ExternalFeed::Manager) orchestrates provider and caching
3. **Provider** (e.g., ResalesOnline) handles API communication and data normalization
4. **Normalized Data** structures (NormalizedProperty, NormalizedSearchResult) ensure consistency
5. **Cache** stores results for performance
6. **Views** render search results, filters, and property details with translations

---

## 1. Controllers

### Files
- `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/site/external_listings_controller.rb`
- `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/external_feeds_controller.rb`

### ExternalListingsController (Frontend)

**Namespace:** `Pwb::Site`

**Actions:**
- `index` - Display search results with filters (also handles `search` as alias)
- `show` - Display individual property details
- `similar` - Get similar properties (AJAX endpoint)
- `locations` - JSON endpoint for filter locations
- `property_types` - JSON endpoint for filter property types
- `filters` - JSON endpoint for all filter options

**Key Methods:**

```ruby
def index
  @search_params = search_params
  @result = external_feed.search(@search_params)
  @filter_options = external_feed.filter_options(locale: I18n.locale)
  # Responds to both HTML and JSON
end

def show
  # Finds property, checks if available
  # Handles sold/rented statuses with translated messages
  # Loads similar properties (limit: 6)
end

def similar
  # Returns similar properties as partial or JSON
  # Supports customizable limit (1-20)
end
```

**Filter Parameters (permitted):**
```ruby
:listing_type (symbol: sale/rental)
:location
:min_price, :max_price
:min_bedrooms, :max_bedrooms
:min_bathrooms, :max_bathrooms
:min_area, :max_area
:sort
:page, :per_page
property_types: []
features: []
```

**Translations Used:**
- `external_feed.search.title`
- `external_feed.search.subtitle`
- `external_feed.status.sold`, `.rented`, `.unavailable`
- `external_feed.search.showing` (with %{range} placeholder)
- `external_feed.search.no_results`
- Various breadcrumb and feature translations

### ExternalFeedsController (Admin)

**Namespace:** `SiteAdmin`

**Actions:**
- `show` - Display feed configuration form
- `update` - Update feed settings
- `test_connection` - Test API connectivity
- `clear_cache` - Clear cached results

**Config Fields** (for Resales Online):
- `api_key` (password type, required)
- `api_id_sales` (required for sales listings)
- `api_id_rentals` (optional for rental listings)
- `p1_constant` (optional, uses default if not set)

---

## 2. Views

### Directory
`/Users/etewiah/dev/sites-older/property_web_builder/app/views/pwb/site/external_listings/`

### Files

#### `index.html.erb` - Search Results Page
- **Layout:** 4-column grid (1 filter sidebar + 3 result columns on desktop)
- **Components:**
  - Header with title and subtitle
  - Filter sidebar (rendered from `_search_form.html.erb`)
  - Results header (showing/no results message)
  - Sort dropdown (changes listing type)
  - Save search button (opens modal)
  - Error alert (if search fails)
  - Property grid (3-column responsive)
  - Pagination (if results > 1 page)
  - Empty state message

**Key JavaScript Functions:**
- `updateSort(value)` - Updates URL with new sort parameter
- `openSaveSearchModal()` / `closeSaveSearchModal()`
- `toggleFavorite(event, reference, title)` / `closeFavoriteModal()`
- Escape key handler for modals

**Modals:**
1. **Save Search Modal** - Email, name, alert frequency
2. **Favorite Modal** - Email, notes for saving property

#### `show.html.erb` - Property Detail Page
- **Layout:** 2-column (2/3 main content, 1/3 sidebar on desktop)
- **Main Content:**
  - Breadcrumb navigation
  - Image gallery with thumbnails
  - Property title and location
  - Key features bar (bedrooms, bathrooms, areas)
  - Description
  - Features list (checkmarked)
  - Energy rating
  - Map (if coordinates available)
  - Similar properties section
  - Contact form section

- **Sidebar:**
  - Price card (with badge for listing type)
  - Price reduction badge (if applicable)
  - Contact buttons (Contact Agent, Call Now)
  - Property details card (structured key-value pairs)
  - Share card (social media links: Facebook, Twitter, WhatsApp, Email)

#### `_search_form.html.erb` - Filter Sidebar
- **Form Type:** GET request to `external_listings_path`
- **Filter Sections:**
  1. Listing Type (radio buttons: Buy/Rent)
  2. Location (dropdown)
  3. Property Types (checkboxes with overflow scrolling)
  4. Price Range (min/max number inputs)
  5. Bedrooms (min/max selects, 1-10)
  6. Bathrooms (min/max selects, 1-8)
  7. Area m² (min/max number inputs)
  8. Features (conditional checkboxes with overflow)
  9. Apply Filters button
  10. Clear Filters link

**Translations:**
- Uses `t()` helper with defaults for all labels
- `external_feed.search.*` key namespace
- `external_feed.listing_type.*` for Buy/Rent labels
- `external_feed.listing_types.*` (note: plural in some contexts)

#### `_property_card.html.erb` - Grid Card Component
- **Image Section:**
  - Main image with lazy loading or placeholder
  - Status badge (For Rent/For Sale)
  - Price reduced badge
  - Favorite button (heart icon)
  - Image count indicator

- **Details Section:**
  - Price (formatted)
  - Rental period (if applicable)
  - Title (with link, single line clamp)
  - Location (with icon, single line clamp)
  - Feature icons and values:
    - Bedrooms (bedroom icon)
    - Bathrooms (bathroom icon)
    - Built area m² (size icon)
    - Property type (right-aligned small text)

#### `_pagination.html.erb` - Pagination Component
- **Mobile View:** Previous/Next buttons only
- **Desktop View:**
  - Previous button
  - Page numbers with smart window display:
    - Always shows first page
    - Shows window around current (±2 pages)
    - Shows last page
    - Ellipsis for gaps
  - Next button
  - Results range text: "Showing X-Y of Z results"

#### `_similar.html.erb` - Similar Properties Grid
- Simple 3-column responsive grid
- Uses `_property_card.html.erb` for each property

#### `unavailable.html.erb` - Property Unavailable Page
- Returns 410 Gone HTTP status
- Displays status message (sold/rented/unavailable)
- Message is translated based on listing status

---

## 3. JavaScript & Stimulus Controllers

### Files
- `/Users/etewiah/dev/sites-older/property_web_builder/app/javascript/controllers/filter_controller.js`

### FilterController

**Type:** Stimulus.js Controller

**Targets:**
- `panel` - Filter panel container
- `form` - Filter form element
- `count` - Element showing active filter count
- `input` - Form inputs (for tracking changes)

**Values:**
- `submitOnChange` (boolean) - Auto-submit form on filter change
- `debounce` (number) - Debounce delay in ms (default: 300)

**Actions:**

```javascript
togglePanel()     // Show/hide filter panel
showPanel()       // Show filter panel
hidePanel()       // Hide filter panel
submitOnChange()  // Handle filter change event
submit()          // Submit form via requestSubmit()
debounceSubmit()  // Debounced form submission
clear()           // Reset all filters and submit
updateCount()     // Update active filter count display
```

**Features:**
- Counts active filters (non-empty values)
- Updates count display as user changes filters
- Debounces form submission to avoid excessive requests
- Clears form: resets inputs, clears selects, unchecks checkboxes
- Shows filter count like "3 filters" or "1 filter"

---

## 4. Data Models

### NormalizedProperty

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/external_feed/normalized_property.rb`

**Purpose:** Unified property data structure for all providers

**Key Attributes:**

| Category | Attributes |
|----------|-----------|
| **Identification** | `reference`, `provider`, `provider_url` |
| **Basic Info** | `title`, `description`, `property_type`, `property_type_raw`, `property_subtype` |
| **Location** | `country`, `region`, `area`, `city`, `address`, `postal_code`, `latitude`, `longitude`, `location`, `province` |
| **Listing Details** | `listing_type` (:sale/:rental), `status`, `price`, `price_raw`, `currency`, `price_qualifier`, `original_price` |
| **Rental** | `rental_period`, `available_from`, `minimum_stay`, `price_frequency` |
| **Property Details** | `bedrooms`, `bathrooms`, `built_area`, `plot_area`, `terrace_area`, `year_built`, `floors`, `floor_level`, `orientation`, `parking_spaces` |
| **Features** | `features` (array), `features_by_category` (hash) |
| **Energy** | `energy_rating` (A-G), `energy_value`, `co2_rating`, `co2_value`, `energy_consumption` |
| **Media** | `images` (array of hashes), `virtual_tour_url`, `video_url`, `floor_plan_urls` |
| **Costs** | `community_fees`, `ibi_tax`, `garbage_tax` |
| **Metadata** | `created_at`, `updated_at`, `fetched_at` |

**Methods:**
```ruby
def formatted_price           # Currency-formatted price
def main_image                # First image URL
def available?                # Status check
def price_reduced?            # Price comparison check
def to_h                       # Hash conversion for JSON
```

### NormalizedSearchResult

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/external_feed/normalized_search_result.rb`

**Purpose:** Pagination and metadata wrapper for search results

**Attributes:**
- `properties` - Array<NormalizedProperty>
- `total_count` - Total matching properties
- `page` - Current page (1-indexed)
- `per_page` - Results per page
- `total_pages` - Calculated from total_count and per_page
- `query_params` - Original search parameters
- `provider` - Provider name (symbol)
- `fetched_at` - Fetch timestamp
- `error` - Error message if search failed

**Key Methods:**
```ruby
current_page              # Alias for page
first_page?, last_page?   # Boolean checks
next_page, prev_page      # Pagination navigation
has_next_page?, has_prev_page?
page_range(window: 2)     # Returns range for pagination display
error?, success?          # Status checks
empty?, any?              # Collection checks
count, size, first, last  # Collection access
offset                    # 0-indexed offset for current page
results_range             # Returns "X-Y of Z" string
to_h, as_json             # Serialization
each, map, select         # Enumerable methods
```

---

## 5. Service Layer

### Manager

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/external_feed/manager.rb`

**Purpose:** Orchestrates provider operations and caching

**Key Methods:**

```ruby
provider                      # Get configured provider instance
enabled?                      # Check if feed is accessible
configured?                   # Check if provider is set up

search(params)                # Search properties, returns NormalizedSearchResult
find(reference, params)       # Get single property, returns NormalizedProperty
similar(property, params)     # Find similar properties, returns Array<NormalizedProperty>

locations(params)             # Get location options for filters
property_types(params)        # Get property type options
filter_options(params)        # Get all filter options (returns hash with sort_options too)
```

**Caching:**
- Uses CacheStore for all operations
- Automatically caches search results, property details, similar properties
- Cache invalidation on configuration changes
- Configurable TTL per cache store

**Error Handling:**
- Rescues all ExternalFeed::Error subclasses
- Returns empty/nil results gracefully
- Logs errors for debugging
- Returns error results with error messages

### BaseProvider (Abstract)

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/external_feed/base_provider.rb`

**Purpose:** Abstract base for provider implementations

**Methods (must be implemented):**
```ruby
def search(params)                # Returns NormalizedSearchResult
def find(reference, params)       # Returns NormalizedProperty
def similar(property, params)     # Returns Array<NormalizedProperty>
def locations(params)             # Returns Array<{value:, label:}>
def property_types(params)        # Returns Array<{value:, label:}>
def available?                    # Returns boolean
def self.provider_name            # Returns symbol (e.g., :resales_online)
def self.display_name             # Returns string for UI
```

**Protected Methods:**
```ruby
def validate_config!              # Validates required config keys
```

### ResalesOnline Provider

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/external_feed/providers/resales_online.rb`

**API Endpoints:**
- Search (Sales): `https://webapi.resales-online.com/WebApi/V6/SearchProperties.php`
- Search (Rentals): `https://webapi.resales-online.com/WebApi/V5-2/SearchProperties.php`
- Details: `https://webapi.resales-online.com/WebApi/V6/PropertyDetails.php`

**Configuration Required:**
- `api_key` - API authentication key
- `api_id_sales` - API ID for sales listings
- Optional: `api_id_rentals` - API ID for rentals (falls back to sales ID)
- Optional: `p1_constant` - P1 constant for API calls (defaults to "1014359")

**Language Support:**
Supports 11 languages via LANG_CODES mapping:
- en (1), es (2), de (3), fr (4), nl (5)
- da (6), ru (7), sv (8), pl (9), no (10), tr (11)

**Sort Options:**
- `price_asc` (0) - Price Low to High
- `price_desc` (1) - Price High to Low
- `location` (2) - By Location
- `newest` (3) - Newest First
- `oldest` (4) - Oldest First
- `listed_newest` (5) - Listed Newest
- `listed_oldest` (6) - Listed Oldest
- `updated` (3) - Recently Updated

**Search Parameter Mapping:**
```ruby
p_PageNo        <- page (if > 1)
p_PageSize      <- per_page (default: 24)
p_PropertyTypes <- property_types (comma-separated)
p_Location      <- location
p_Beds          <- min_bedrooms (format: "Nx")
p_Baths         <- min_bathrooms (format: "Nx")
p_Min           <- min_price
p_Max           <- max_price
p_SortType      <- sort
P_Lang          <- locale
P_Country       <- default_country (default: Spain)
P_Images        <- image_count (default: 0 = all)
```

**Error Handling:**
- `AuthenticationError` (401/403)
- `RateLimitError` (429)
- `PropertyNotFoundError` (404)
- `ProviderUnavailableError` (500+, timeouts)
- `InvalidResponseError` (invalid JSON)
- Timeout handling (30s read, 10s connect)

**Response Normalization:**
- Normalizes nested API response structure
- Handles single property as hash or array
- Extracts and formats price, location, images, features
- Maps property types to normalized codes
- Parses coordinates for map integration
- Handles sold/off-market status flags

---

## 6. Translations

### Translation Key Namespace

All external feed translations use the `external_feed` namespace.

### Common Keys Used in Views

**Search Page:**
```yaml
external_feed:
  search:
    title              # "Property Search"
    subtitle           # "Browse available properties..."
    filters            # "Filters"
    listing_type       # "Listing Type"
    location           # "Location"
    any_location       # "Any Location"
    property_type      # "Property Type"
    price_range        # "Price Range"
    min, max           # "Min", "Max"
    bedrooms           # "Bedrooms"
    bathrooms          # "Bathrooms"
    area               # "Area (m²)"
    features           # "Features"
    apply_filters      # "Apply Filters"
    clear_filters      # "Clear Filters"
    sort_by            # "Sort by:"
    showing            # "Showing %{range} properties" (with variable)
    no_results         # "No properties found"
    no_properties      # "No properties found"
    try_different      # "Try adjusting your search filters"
    error              # "Unable to load properties at this time..."
  
  listing_type:
    sale               # "For Sale"
    rental             # "For Rent"
  
  listing_types:
    sale               # "Buy" (in radio buttons)
    rental             # "Rent"
  
  sort:
    price_asc          # "Price (Low to High)"
    price_desc         # "Price (High to Low)"
    newest             # "Newest First"
    updated            # "Recently Updated"
  
  pagination:
    previous           # "Previous"
    next               # "Next"
    showing_results    # "Showing %{range} of %{total} results"
  
  badges:
    reduced            # "Price Reduced"
  
  property_types:
    apartment          # "Apartment"
    house              # "House"
    villa              # "Villa"
    # ... other types
  
  features:
    bedrooms           # "Bedrooms"
    bathrooms          # "Bathrooms"
    built_area         # "Built Area"
    built_area_m2      # "m² Built"
    plot_area          # "Plot Area"
    plot_area_m2       # "m² Plot"
    terrace            # "Terrace"
    parking            # "Parking"
    year_built         # "Year Built"
    orientation        # "Orientation"
  
  frequency:
    month              # "Month" (for rental period)
    week               # "Week"
    day                # "Day"
```

**Property Detail Page:**
```yaml
external_feed:
  breadcrumb:
    home               # "Home"
    sales              # "Properties for Sale"
    rentals            # "Rentals"
  
  property:
    reference          # "Ref:"
    description        # "Description"
    features           # "Features"
    energy             # "Energy Rating"
    energy_rating      # "Energy Rating"
    energy_consumption # "Consumption"
    location_map       # "Location"
    map_loading        # "Map loading..."
    details            # "Property Details"
    type               # "Type"
    contact_agent      # "Contact Agent"
    call_now           # "Call Now"
    share              # "Share Property"
    similar            # "Similar Properties"
    inquire            # "Inquire About This Property"
    contact_info       # "Please contact us for more information..."
  
  status:
    sold               # "This property has been sold"
    rented             # "This property has been rented"
    unavailable        # "This property is no longer available"
  
  not_configured       # "External listings are not available"
```

**Translations are passed via I18n:**
```ruby
t("external_feed.search.title", default: "Property Search")
t("external_feed.property_types.#{property.property_type}", default: property.property_type.titleize)
```

---

## 7. Routing

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/config/routes.rb`

**Admin Routes:**
```ruby
resource :external_feed, only: %i[show update] do
  member do
    post :test_connection
    post :clear_cache
  end
end
```
- `GET /site_admin/external_feed` - Show configuration
- `PATCH /site_admin/external_feed` - Update configuration
- `POST /site_admin/external_feed/test_connection` - Test API
- `POST /site_admin/external_feed/clear_cache` - Clear cache

**Frontend Routes:**
```ruby
resources :external_listings, only: [:index, :show], param: :reference do
  member do
    get :similar
  end
  collection do
    get :locations
    get :property_types
    get :filters
  end
end
```
- `GET /external_listings` - Search/browse (also handles `/external_listings/search`)
- `GET /external_listings/:reference` - Property detail
- `GET /external_listings/:reference/similar` - Similar properties
- `GET /external_listings/locations` - JSON locations list
- `GET /external_listings/property_types` - JSON property types list
- `GET /external_listings/filters` - JSON all filter options

---

## 8. Initialization & Configuration

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/config/initializers/external_feeds.rb`

**Purpose:**
- Registers available provider implementations
- Uses `Rails.application.config.to_prepare` for hot-reloading in development
- Currently registers: `Pwb::ExternalFeed::Providers::ResalesOnline`

**To Add New Providers:**
1. Create class in `app/services/pwb/external_feed/providers/`
2. Inherit from `BaseProvider`
3. Implement all abstract methods
4. Register in this initializer with `Pwb::ExternalFeed::Registry.register(ProviderClass)`

---

## 9. Caching Strategy

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/external_feed/cache_store.rb`

**Cache Operations:**
- Stores search results
- Stores property details
- Stores similar properties
- Stores filter options (locations, property types)

**Cache Invalidation:**
- Manual: Call `invalidate_cache` on feed manager
- Automatic: Configure TTL per cache type
- Triggers: Configuration changes call `invalidate_cache`

**Performance:**
- Reduces API calls for repeated searches
- Caches per website (multi-tenant safe)
- Prevents thundering herd on popular searches

---

## 10. Stimulus Controller Integration

The filter form uses Stimulus controller for dynamic behavior:

```erb
<div data-controller="filter" data-filter-submit-on-change-value="true">
  <form data-filter-target="form" data-action="change->filter#submitOnChange">
    <!-- filter inputs -->
  </form>
  <span data-filter-target="count">No filters</span>
  <button data-action="filter#clear">Clear All</button>
</div>
```

**User Flow:**
1. User changes any filter (radio, checkbox, select, input)
2. Change event triggers `submitOnChange`
3. `updateCount()` updates the filter count display
4. If `submitOnChange` is enabled, form auto-submits after debounce

---

## 11. Current Limitations & Considerations

### Translations
- Translations are defined inline in views with defaults
- No centralized translation file found - check for YAML files or use I18n dynamic resolution
- Property types and features are dynamically translated from provider data

### Filter Options
- Hard-coded bedrooms (1-10 for max) and bathrooms (1-8 for max)
- Property types and locations come from provider (or config fallback)
- Features are conditional based on provider capabilities

### Frontend JavaScript
- Simple inline JavaScript in views (not extracted to separate files)
- Modal handling is basic HTML/CSS visibility toggle
- No complex AJAX filtering - forms submit traditional GET requests

### Multi-language
- Translations use I18n with locale passed to providers
- Providers handle language-specific data (ResalesOnline supports 11 languages)
- Locale is passed from `I18n.locale` throughout the stack

### Error Handling
- Search errors show yellow alert box
- Property not found returns 404-like view
- Unavailable properties return 410 Gone status
- No error logging to user-facing dashboards

---

## 12. Summary of Key Points

**Architecture Strengths:**
- Clean separation: Controller → Manager → Provider → Normalized Data
- Multi-provider ready (easy to add new providers)
- Comprehensive caching system
- Proper error handling and logging
- Multi-language support throughout
- SEO-friendly URL routing with property references

**Translation Pattern:**
- Views use `t()` with `external_feed.` namespace
- Defaults provided for all keys
- Locale passed explicitly to providers
- Dynamic translation of property types and features

**Filter Design:**
- Server-side form submission (no AJAX)
- Stimulus controller for UI polish (count, debounce)
- All filter parameters are preserved in query string
- Responsive design: sidebar on desktop, hidden on mobile

**Performance:**
- Caching layer prevents excessive API calls
- Lazy loading on images
- Pagination limits results per page (default 24)
- Similar properties limited to 6-8 results

**Extensibility:**
- Provider registry pattern for adding new sources
- BaseProvider abstract class for consistent interface
- Normalized data structures for consistent view rendering
- Configuration per website (multi-tenant)
