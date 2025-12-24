# PropertyWebBuilder Search Architecture - Comprehensive Analysis

## Executive Summary

The PropertyWebBuilder search system is a **server-rendered, AJAX-based search interface** that allows users to filter property listings. It uses a combination of Rails controllers, Stimulus JS controllers, and server-side scoping to provide real-time search results.

**Current Status:** Functional but with architectural limitations around state management and UX.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Routes & Endpoints](#routes--endpoints)
3. [Controllers](#controllers)
4. [Search Models & Scopes](#search-models--scopes)
5. [Views & Templates](#views--templates)
6. [JavaScript & Stimulus](#javascript--stimulus)
7. [Services](#services)
8. [URL Parameter Handling](#url-parameter-handling)
9. [Pain Points & Limitations](#pain-points--limitations)
10. [Data Flow Diagrams](#data-flow-diagrams)

---

## Architecture Overview

### Technology Stack

- **Backend:** Rails 7.x with server-side rendering
- **Frontend:** ERB templates + Liquid templates (themes)
- **Styling:** Tailwind CSS + Bootstrap remnants
- **JavaScript:** Stimulus.js controllers + inline scripts
- **HTTP Communication:** AJAX via Rails UJS (`remote: true`)
- **State Management:** URL parameters (GET) + Form submission (POST)

### Search Types

1. **Buy/Sale Search:** `/buy` and `/buy?search[parameters]`
2. **Rent Search:** `/rent` and `/rent?search[parameters]`
3. **AJAX Updates:** POST to `/search_ajax_for_sale` or `/search_ajax_for_rent`

---

## Routes & Endpoints

### Public Routes (with locale prefix)

```ruby
# Main search pages (GET)
get "/buy" => "search#buy"
get "/rent" => "search#rent"

# AJAX endpoints (POST)
post "/search_ajax_for_sale" => "search#search_ajax_for_sale"
post "/search_ajax_for_rent" => "search#search_ajax_for_rent"
```

Location: `/config/routes.rb` (lines 331-336)

---

## Controllers

### Main Controller: `Pwb::SearchController`

**File:** `/app/controllers/pwb/search_controller.rb`

#### Public Actions

```ruby
# GET /buy
def buy
  perform_search(operation_type: "for_sale", page_slug: "buy")
end

# GET /rent
def rent
  perform_search(operation_type: "for_rent", page_slug: "rent")
end

# POST /search_ajax_for_sale.js
def search_ajax_for_sale
  perform_ajax_search(operation_type: "for_sale")
end

# POST /search_ajax_for_rent.js
def search_ajax_for_rent
  perform_ajax_search(operation_type: "for_rent")
end
```

#### Private Methods

| Method | Purpose |
|--------|---------|
| `perform_ajax_search` | Handles POST requests, applies filters, renders JS template |
| `perform_search` | Handles GET requests, sets up page, applies filters, loads facets |
| `search_config_for` | Returns price range options based on operation type |
| `load_properties_for` | Gets base property scope scoped to website and operation type |
| `setup_page` | Loads page object and sets SEO title |
| `calculate_facets` | Computes filter counts via SearchFacetsService |
| `facets_cache_key` | Generates cache key for facet results |
| `normalize_url_params` | Converts friendly URL params to search params |

#### Included Concerns

```ruby
include SearchUrlHelper        # URL helpers for SEO-friendly links
include SeoHelper              # SEO-related methods
include Search::PropertyFiltering  # Filter application logic
include Search::MapMarkers     # Map marker generation
include Search::FormSetup      # Form field setup
```

---

## Search Concerns

### 1. Property Filtering (`Search::PropertyFiltering`)

**File:** `/app/controllers/concerns/search/property_filtering.rb`

Handles extraction and application of search filters.

#### Key Methods

```ruby
# Extract filter params from request
filtering_params(params)
  # Returns: {in_locality, in_zone, for_sale_price_from, for_sale_price_till, 
  #          for_rent_price_from, for_rent_price_till, property_type, 
  #          property_state, count_bathrooms, count_bedrooms}

# Extract feature/amenity filters
feature_params()
  # Returns: {features: [...], features_match: 'all'|'any'}

# Apply filters to @properties relation
apply_search_filter(search_filtering_params)

# Check if param is a price field
price_field?(key)

# Convert price to cents
convert_price_to_cents(value)

# Apply feature filters
apply_feature_filters()

# Parse feature keys from string or array
parse_feature_keys(features_param)
```

#### Filter Parameters Supported

| Parameter | Type | Example | Usage |
|-----------|------|---------|-------|
| `in_locality` | String | "madrid" | Location scope |
| `in_zone` | String | "zona-norte" | Sub-location scope |
| `for_sale_price_from` | Integer | "100000" | Minimum sale price (cents) |
| `for_sale_price_till` | Integer | "500000" | Maximum sale price (cents) |
| `for_rent_price_from` | Integer | "1000" | Minimum rental price (cents) |
| `for_rent_price_till` | Integer | "3000" | Maximum rental price (cents) |
| `property_type` | String | "types.apartment" | Property type filter |
| `property_state` | String | "states.new_build" | Property state filter |
| `count_bathrooms` | Integer | "2" | Minimum bathrooms |
| `count_bedrooms` | Integer | "3" | Minimum bedrooms |
| `features` | Array | ["features.pool", "features.sea_views"] | Property features |
| `features_match` | String | "all" \| "any" | Feature matching logic |

### 2. Map Markers (`Search::MapMarkers`)

**File:** `/app/controllers/concerns/search/map_markers.rb`

Generates marker data for property map display.

#### Methods

```ruby
# Generate markers for all properties
set_map_markers()
  # Sets @map_markers with filtered properties that have coordinates

# Build single marker
build_marker_data(property)
  # Returns: {id, title, show_url, image_url, display_price, position: {lat, lng}}
```

### 3. Form Setup (`Search::FormSetup`)

**File:** `/app/controllers/concerns/search/form_setup.rb`

Sets up dropdown options and form data.

#### Methods

```ruby
# Load filter options from FieldKey system
set_common_search_inputs()
  # Sets: @property_types, @property_states, @property_features, @property_amenities

# Set localized select picker texts
set_select_picker_texts()
  # Sets: @select_picker_texts JSON with translations

# Get header image from landing page
header_image_url()
  # Sets: @header_image_url
```

---

## Search Models & Scopes

### Primary Model: `Pwb::ListedProperty`

**File:** `/app/models/pwb/listed_property.rb`

Represents a searchable property listing in a website.

#### Searchable Concern

**File:** `/app/models/concerns/listed_property/searchable.rb`

Provides all search-related scopes and filtering logic.

#### Available Scopes

```ruby
# Visibility & Operation Type
.visible                       # where(visible: true)
.for_sale                      # where(for_sale: true)
.for_rent                       # where(for_rent: true)
.highlighted                    # where(highlighted: true)

# Property Classification
.property_type(type_key)        # where(prop_type_key: value)
.property_state(state_key)      # where(prop_state_key: value)

# Price Ranges (expects cents)
.for_sale_price_from(min)       # where(price_sale_current_cents >= min)
.for_sale_price_till(max)       # where(price_sale_current_cents <= max)
.for_rent_price_from(min)       # where(price_rental_monthly_for_search_cents >= min)
.for_rent_price_till(max)       # where(price_rental_monthly_for_search_cents <= max)

# Room Counts (minimum counts)
.count_bathrooms(min)           # where(count_bathrooms >= min)
.count_bedrooms(min)            # where(count_bedrooms >= min)
.bathrooms_from(min)            # Alias for count_bathrooms
.bedrooms_from(min)             # Alias for count_bedrooms

# Feature Search
.with_features(keys)            # Properties WITH ALL features (AND logic)
.with_any_features(keys)        # Properties WITH ANY feature (OR logic)
.without_features(keys)         # Properties WITHOUT specified features

# Eager Loading
.with_eager_loading             # includes(:website, :prop_photos)
```

#### Feature Filter Logic

**All Features (AND):**
```ruby
scope :with_features, ->(feature_keys) {
  property_ids = PwbTenant::Feature
    .where(feature_key: feature_array)
    .group(:realty_asset_id)
    .having("COUNT(DISTINCT feature_key) = ?", feature_array.length)
    .select(:realty_asset_id)
  where(id: property_ids)
}
```

**Any Feature (OR):**
```ruby
scope :with_any_features, ->(feature_keys) {
  property_ids = PwbTenant::Feature
    .where(feature_key: feature_array)
    .select(:realty_asset_id)
    .distinct
  where(id: property_ids)
}
```

---

## Views & Templates

### View Structure

```
app/views/pwb/search/
├── buy.html.erb                    # Fallback buy page (rarely used)
├── rent.html.erb                   # Fallback rent page (rarely used)
├── search_ajax.js.erb              # AJAX response template
├── _search_form_for_sale.html.erb  # Buy search form partial
├── _search_form_for_rent.html.erb  # Rent search form partial
├── _search_form_landing.html.erb   # Landing page search form
├── _search_results.html.erb        # Search results list
├── _search_result_item.html.erb    # Individual result card
└── _feature_filters.html.erb       # Feature/amenity checkboxes

app/themes/*/views/pwb/search/
├── buy.html.erb                    # Theme-specific buy page
├── rent.html.erb                   # Theme-specific rent page
├── _search_results.html.erb        # Theme-specific results
├── _search_form_for_sale.html.erb  # Theme-specific form
├── _search_form_for_rent.html.erb
└── _search_form_landing.html.erb
```

### Key Templates

#### 1. Search Form Partial

**File:** `/app/views/pwb/search/_search_form_for_sale.html.erb`

Uses Rails `simple_form` with:
- Price range selects
- Property type dropdown
- Location dropdowns (zone, locality)
- Room count selects
- Feature/amenity checkboxes
- Search button

**Important:** Uses `remote: true` to submit via AJAX

#### 2. Search Results Partial

**File:** `/app/views/pwb/search/_search_results.html.erb`

```erb
<div id="resp_buscar_inmuebles">
  <ul class="list-listings" id="ordered-properties">
    <!-- No results message or property cards -->
  </ul>
</div>
```

Structure:
- Container: `div#resp_buscar_inmuebles`
- Results list: `ul#ordered-properties`
- Each item: Rendered via `_search_result_item` partial

#### 3. Feature Filters Partial

**File:** `/app/views/pwb/search/_feature_filters.html.erb`

Displays:
- Feature checkboxes with facet counts
- Amenity checkboxes with facet counts
- Feature match selector (all/any)

Features:
- Shows counts from `@facets` if available
- Disables options with count=0
- Shows/hides match selector based on selection

#### 4. AJAX Response Template

**File:** `/app/views/pwb/search/search_ajax.js.erb`

```javascript
// Update results HTML
var resultsContainer = document.getElementById('inmo-search-results');
if (resultsContainer) {
  resultsContainer.innerHTML = "<%= j (render 'search_results') %>";
}

// Update map markers
var markers = <%= @map_markers.to_json.html_safe %>;
var mapElement = document.querySelector('[data-controller~="map"]');
if (mapElement && mapElement.mapController) {
  mapElement.mapController.updateMarkers(markers);
}

// Trigger custom event for Stimulus controllers
document.dispatchEvent(new CustomEvent('search:updated', {
  detail: { markers: markers }
}));
```

#### 5. Default Buy Page (Theme: default)

**File:** `/app/themes/default/views/pwb/search/buy.html.erb`

Modern layout using Tailwind CSS with:
- Breadcrumb navigation
- Filter toggle button (mobile)
- Sidebar with search form and filters
- Results area with loading spinner
- Map section below results

---

## JavaScript & Stimulus

### Stimulus Controller: SearchFormController

**File:** `/app/javascript/controllers/search_form_controller.js`

Handles client-side AJAX search form interactions.

#### Targets

```javascript
static targets = ["form", "results", "spinner"]
```

#### Event Handlers

```javascript
connect()                    // Bind event listeners
disconnect()                 // Unbind listeners
showLoading()                // Show spinner
hideLoading()                // Hide spinner
handleSuccess()              // Post-AJAX success (truncate, sort, update URL)
handleError()                // AJAX error handling
truncateDescriptions()       // Limit description length
sortResults()                // Sort by price
updateUrlParams()            // Push search params to browser history
toggleFilters()              // Mobile filter sidebar toggle
```

#### Rails UJS Events

```javascript
form.addEventListener("ajax:beforeSend", showLoading)
form.addEventListener("ajax:complete", hideLoading)
form.addEventListener("ajax:success", handleSuccess)
form.addEventListener("ajax:error", handleError)
```

**Note:** Uses deprecated Rails UJS events

### Inline Scripts

#### Clear Filters Function

Located in `_search_results.html.erb`:

```javascript
function clearSearchFilters() {
  var form = document.querySelector('form.form-light') || 
             document.querySelector('form.simple_form');
  if (form) {
    form.reset();
    // ... clear various input types ...
    form.dispatchEvent(new Event('submit', { bubbles: true }));
  }
}
```

#### Feature Match Selector

Located in `_feature_filters.html.erb`:

```javascript
document.addEventListener('DOMContentLoaded', function() {
  var checkboxes = document.querySelectorAll('.feature-checkbox');
  var matchSection = document.getElementById('features-match-section');
  
  function updateMatchSectionVisibility() {
    var anyChecked = Array.from(checkboxes).some(cb => cb.checked);
    matchSection.style.display = anyChecked ? 'block' : 'none';
  }
  
  checkboxes.forEach(cb => cb.addEventListener('change', updateMatchSectionVisibility));
  updateMatchSectionVisibility();
});
```

---

## Services

### 1. SearchFacetsService

**File:** `/app/services/pwb/search_facets_service.rb`

Calculates filter counts based on current search results.

#### Main Method

```ruby
def self.calculate(scope:, website:, operation_type: nil)
  {
    property_types: calculate_property_types(scope, website),
    property_states: calculate_property_states(scope, website),
    features: calculate_features(scope, website),
    amenities: calculate_amenities(scope, website),
    bedrooms: calculate_bedrooms(scope),
    bathrooms: calculate_bathrooms(scope)
  }
end
```

#### Facet Methods

| Method | Returns |
|--------|---------|
| `calculate_property_types` | Array of {global_key, value, label, count} |
| `calculate_property_states` | Array of {global_key, value, label, count} |
| `calculate_features` | Array of features with counts |
| `calculate_amenities` | Array of amenities with counts |
| `calculate_bedrooms` | Array of bedroom counts with distribution |
| `calculate_bathrooms` | Array of bathroom counts with distribution |

#### Output Format

```ruby
{
  global_key: 'features.private_pool',
  value: 'features.private_pool',
  label: 'Swimming Pool',  # Translated via Mobility
  count: 42
}
```

#### Caching (5 minutes)

```ruby
cache_key = ["search_facets", website.id, operation_type, locale, website.updated_at.to_i].join("/")
@facets = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
  SearchFacetsService.calculate(...)
end
```

### 2. SearchParamsService (Planned)

**Status:** Tests exist but service not yet implemented

**File:** `/spec/services/pwb/search_params_service_spec.rb` (specifications only)

**Planned Functionality:**

```ruby
# Parse URL parameters
from_url_params(params)

# Generate URL parameters
to_url_params(criteria)

# Generate canonical search URL
canonical_url(criteria, locale:, operation:, host:)
```

---

## URL Parameter Handling

### Parameter Formats

#### 1. Traditional Format (nested under `search`)

```
/buy?search[property_type]=types.apartment&search[count_bedrooms]=3
```

#### 2. Friendly Format (flat URL)

```
/buy?type=apartment&bedrooms=3&features=pool,sea-views
```

### Helper: `SearchUrlHelper`

**File:** `/app/helpers/pwb/search_url_helper.rb`

#### Key Methods

```ruby
# Convert global_key to URL slug
feature_to_slug('features.private_pool')
  # => 'private-pool'

# Convert URL slug to global_key
slug_to_feature('private-pool', 'property-features')
  # => 'features.private_pool'

# Build SEO-friendly search URL
search_url_with_features(
  base_path: '/buy',
  features: ['features.pool', 'features.sea_views'],
  type: 'types.apartment',
  bedrooms: 3
)

# Parse friendly params
parse_friendly_url_params({type: 'apartment', features: 'pool,sea-views'})

# Generate canonical URL
canonical_search_url(operation_type: 'for_sale', search_params: {...})

# Build filter description
search_filter_description({property_type: 'types.apartment'})
```

---

## Pain Points & Limitations

### 1. State Management

**Issue:** Search state is not properly preserved in URL

- POST-based AJAX means no browser history
- Back button doesn't work
- Can't share/bookmark searches
- URL stays at `/buy` regardless of filters

### 2. Form/Filter Interactions

**Issue:** Filter updates require explicit form submission

- Users must click search button
- No real-time filter updates
- Feature match selector UI feels separate

### 3. JavaScript Architecture

**Issue:** Mixed patterns and deprecated technologies

- Uses deprecated Rails UJS (`remote: true`)
- JS.erb templates are fragile
- Inline scripts hard to maintain
- No request cancellation mechanism

### 4. Performance Issues

- Full results re-render on each filter change
- No pagination (45-property limit)
- Facets cached for 5 minutes (stale data possible)
- No lazy loading of images

### 5. Mobile UX

- Filter sidebar not optimal (full screen overlay)
- No swipe gesture support
- Landscape orientation issues

### 6. Accessibility

- No ARIA labels on dynamic content
- Limited live region updates
- No keyboard navigation for feature filters

### 7. Testing Gaps

- Limited SearchController tests
- No E2E tests for search flow
- AJAX response not tested
- Feature interactions not covered

---

## Best Practices for Modifications

### Adding New Filter

1. Update `Search::PropertyFiltering#filtering_params`
2. Add scope to `ListedProperty::Searchable`
3. Add input to search form partial
4. Add facet calculation if needed
5. Add i18n translations
6. Add tests

### Modifying URLs

1. Use `SearchUrlHelper` for slug conversion
2. Update `parse_friendly_url_params`
3. Update `canonical_search_url`
4. Test round-trip consistency

### Modifying AJAX Response

1. Update `search_ajax.js.erb`
2. Add error handling
3. Test with slow networks

---

## Key Files Summary

| File | Purpose |
|------|---------|
| `/app/controllers/pwb/search_controller.rb` | Main controller |
| `/app/controllers/concerns/search/property_filtering.rb` | Filter logic |
| `/app/controllers/concerns/search/map_markers.rb` | Map markers |
| `/app/controllers/concerns/search/form_setup.rb` | Form setup |
| `/app/models/concerns/listed_property/searchable.rb` | Search scopes |
| `/app/services/pwb/search_facets_service.rb` | Facet calculation |
| `/app/helpers/pwb/search_url_helper.rb` | URL helpers |
| `/app/javascript/controllers/search_form_controller.js` | Stimulus controller |
| `/app/views/pwb/search/` | Core search partials |
| `/app/themes/*/views/pwb/search/` | Theme overrides |

---

## Related Documentation

- `/docs/ui/SEARCH_REIMAGINING_PLAN.md` - UX improvement plan
- `/docs/field_keys/field_key_search_implementation.md` - Field key system
- `/docs/architecture/PROPERTY_MODELS_QUICK_REFERENCE.md` - Property models
- `/docs/multi_tenancy/MULTI_TENANCY_QUICK_REFERENCE.md` - Tenant scoping

---

## Summary

**Strengths:**
- Robust server-side filtering
- Faceted search with counts
- Multi-tenancy proper scoping
- SEO-friendly URL helpers
- Basic AJAX functionality

**Limitations:**
- Post-based AJAX breaks browser history
- State not preserved in URL
- JavaScript architecture fragile
- No pagination
- Performance optimization needed

**Next Steps:**
- Implement SearchParamsService
- Move to GET-based AJAX
- Replace Rails UJS with Turbo
- Add pagination
- Implement real-time updates
- Add comprehensive E2E tests
